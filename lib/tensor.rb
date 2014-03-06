# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'deep_merge/rails_compat'
require 'elasticsearch'
require 'active_model'

begin
  require 'active_support/inflector'
rescue LoadError
  nil
end

module Tensor
  class NullLogger
    def method_missing(meth, *args, &block)
      return false
    end
  end

  class ConnectionPool
    def initialize(options={})
      @_connections = {}

      connect()
    end

    class<<self
      def default_options(options={})
        if options.empty?
          @_default_options ||= {
            :log   => false,
            :hosts => ['localhost:9200']
          }
        else
          @_default_options = options
        end

        @_default_options
      end

      def connect(options={}, name=:default)
      # flag to force replacing existing connection instance
        force = options.delete(:force)

      # use default options unless specified
        if options.empty?
          options = default_options()
        end

        @_connections ||= {}

      # initiate connection if new or being forced
        if @_connections[name].nil? or force
          @_connections[name] = Elasticsearch::Client.new(options)
        end

        return @_connections[name]
      end

      def connection(name=:default)
        @_connections[name] rescue nil
      end
    end
  end

  class Model
    include ::ActiveModel::Model
    include ::ActiveModel::Dirty
    extend  ::ActiveModel::Callbacks

    attr_accessor :id
    attr_accessor :type
    attr_reader   :_metadata
    attr_accessor :attributes

    define_model_callbacks :save, :create, :destroy, :update

    DEFAULT_INTERNAL_LIMIT = 1000
    DEFAULT_RESULTS_LIMIT  = 10000
    DEFAULT_MAPPING = {
      'properties' => {
        '_id' => {
          'index' => 'not_analyzed',
          'type'  => 'string'
        },
        '_type' => {
          'index' => 'not_analyzed',
          'type'  => 'string'
        }
      }
    }

    def initialize(attributes={}, options={})
      @attributes ||= {}
      @_dirty = false

    # populate values, don't flag us as dirty
      unless attributes.nil? or attributes.empty?
        from_hash(attributes, {
          :clean => true
        })
      end

      @_metadata = options[:metadata]

      unless @_metadata.nil?
      # set special header values like ID and type
        @_metadata.each do |k,v|
          case k
          when /^_(id|type)$/
            send("#{$1}=", v)
          end
        end
      end
    end

    # populates model attributes from a given hash object
    # +attributes+:: a hash to load into this instance
    # +options+::    options for handling the import process
    # * :ignore_unknown:: boolean, whether to ignore keys in the hash that don't correspond to a field name (true, default) or raise an error (false)
    # * :clean::          boolean, whether attributes updated from this call will mark the instance dirty (false, default) or not (true)
    #
    def from_hash!(attributes, options={})
    # set attributes for each key in the hash
      attributes.stringify_keys().each do |key, value|
        begin
          if key =~ /^_(id|type)$/
            key = $1
          end

        # don't set an attribute unless this key is the name of a field
          if self.fields.keys.include?(key.to_sym)
            @attributes[key] = value
          end

        # hack to temporarily disable "dirty" flagging in attr setter
          @_permaclean = (options[:clean] || false)
          send("#{key}=", value)
          @_permaclean = false


        rescue NoMethodError => e
        # silently drop unknown keys
          if options[:ignore_unknown] === true
            next
          else
            raise e
          end
        end
      end

      return self
    end

    # populates model attributes from a given object, silently discarding unknown keys
    #
    def from_hash(attributes, options={})
      from_hash!(attributes, {
        :ignore_unknown => true
      }.merge(options))

      return self
    end

    # populates model attributes from a given object, firing the *_update callbacks
    def update(attributes)
      run_callbacks :update do
        from_hash(attributes)
      end

      return self
    end

    # persist this instance to the database
    # +options+:: options for save behavior
    # * :reload:: boolean, whether to query the database for the newly-saved object and return that (true, default) or not (false)
    #
    def save(options={}, es_options={})
      run_callbacks :save do
        attempts = 0

        body = self.to_indexed_hash()

        begin
          result = self.class.connection().index({
            :index   => self.class.index_name(),
            :type    => self.class.document_type(),
            :id      => self.id,
            :body    => body,
            :refresh => true
          }.merge(self.class.index_options()).merge(es_options))

        rescue Elasticsearch::Transport::Transport::Errors::BadRequest => e
          message = (MultiJson.load(e.message.gsub(/^\[[0-9]+\]\s+/,'')) rescue nil)
          raise e unless message.is_a?(Hash)

        # handle some error conditions gracefully
          case message.get('error')
          when /^MapperParsingException\[failed to parse \[([^\]]+)\]\].*NumberFormatException\[For input string:/
            STDERR.puts("#{self.id}: Error indexing field #{$1}, truncating...")
            body.unset($1)
            retry
          else
            raise e
          end
        end

      # failed save has failed
        return false unless result['ok'] === true

        self.id = result['_id']

      # unless otherwise specified, make another query to retrieve the object we just saved and update our data
        unless options[:reload] === false
          begin
            self.from_hash(self.class.find(self.id).to_hash())
          rescue Exception
            return false
          end
        end
      end

      return true
    end


    # destroy the current record, firing the *_destroy callbacks
    #
    def destroy(options={})
      run_callbacks :destroy do
        self.class.delete(self.id, options)
      end
    end

    def query(body, options={})
      self.class.query(body, options)
    end

    def fields(name=nil)
      self.class.fields(name)
    end

    def dirty?()
      return @_dirty
    end

    def metadata(key=nil, default=nil)
      rv = (@_metadata || {})
      key = key.to_s
      key = '_'+key unless key =~ /^_/

      return rv.get(key, default) unless key.nil?
      return rv
    end

    def to_hash()
      @attributes.merge({
        :id   => self.id,
        :type => self.type
      }).stringify_keys()
    end

    def to_json()
      MultiJson.dump(to_hash())
    end

    def to_indexed_hash()
      rv = to_hash().stringify_keys()

    # furthermore, always remove id/type from the output
      %w{id _id type _type}.each do |i|
        rv.delete(i)
      end

    # apply defaults for unset fields
    # --------------------------------------------------------------------------
      self.class.fields.each do |k,v|
        if not v.get(:default).nil? and rv[k.to_s].nil? or (rv[k.to_s].respond_to?(:empty?) and rv[k.to_s].empty?)
          rv[k.to_s] = self.send(k.to_sym)
        end
      end

    # what the hell, do it again...
    # (keys in default values for object types may not be strings, this ensures
    # they end up as strings)
    #
      rv = rv.stringify_keys()

    # apply explicitly-defined type definitions
    # --------------------------------------------------------------------------
      typedefs = {}

    # get typedefs from all fields
      self.class.fields.each do |k,v|
        typedefs[k.to_s] = v.get(:typedefs)
      end

    # remove nils
      typedefs.reject!{|k,v| v.nil? or v.empty? }


      return rv.each_recurse do |k,v,p,dhm|
      # apply type definition if one was set
        unless (typedef = typedefs.get(p)).nil?
        # normalize
          typedef = {
            'type' => typedef
          } if typedef.is_a?(String)

          if v.is_a?(Array)
            if typedef['array'] === true
              new_value = v.collect{|i| i.to_s.convert_to(typedef['type']) }
            else
              new_value = nil
            end
          elsif not v.is_a?(Hash)
            new_value = v.to_s.convert_to(typedef['type'])
          else
            new_value = nil
          end

        # update the value
          dhm.set(p, new_value)
        end

        if k =~ /_at$/
          if v.is_a?(String)
            if v.strip.chomp.downcase == 'now'
              v = Time.now
            else
              v = Time.parse(v)
            end
          end

          if v.is_a?(Time)
            new_value = v.strftime('%Y-%m-%dT%H:%M:%S%z')
            dhm.set(p, new_value)
          end
        end
      end
    end


    # def method_missing(meth, *args, &block)
    #   pp meth
    #   pp self.class._fields
    #   raise "FAIL"

    #   super
    # end


    ################################################################################
    # class methods
    #


    # define a valid field name, including type and persistence options
    # Params:
    # +name+:: the name of the field
    # +type+:: the data type of the field (can be :string, :integer, :float, :boolean, :date, :hash; default is :string)
    # +options+::  options for building the field
    # * :array::   boolean, whether to store the field as an array of +type+ values (true) or not (false)
    #
    def self.field(name, type=:string, options={})
      name = name.to_sym
      @_fields ||= {}
      raise "Duplicate field definition #{name}" if @_fields.has_key?(name)

    # register the key definition
      @_fields[name] = {
        :type  => type.to_s.downcase.to_sym,
        :index => case type.to_s.downcase.to_sym
        when :boolean
          :not_analyzed
        else
          options.get(:index)
        end
      }.merge(options)

    # track old dirty values
      define_attribute_methods(@_fields.keys)

    # define getter
      define_method(name) do
        if not instance_variables.include?(:"@#{name}")
          value = self.class._normalize_value(nil, fields(name))

          @attributes[name.to_s] = value
          instance_variable_set(:"@#{name}", value)
        end

        instance_variable_get(:"@#{name}")
      end

    # define setter
      define_method(:"#{name}=") do |value|
      # normalize the value according to type/default rules for this field
        value = self.class._normalize_value(value, fields(name))

        self.send(:"#{name}_will_change!") unless @_permaclean
        instance_variable_set(:"@#{name}", value)
        @attributes[name.to_s] = value


      # flag instance as dirty unless we've stopped doing that because it's not cool anymore...
        @_dirty = true unless @_permaclean

      # return what we just set
        send(name)
      end
    end


    # get the logger instance for output logging
    #
    def self.logger()
      return @@_logger ||= Tensor::NullLogger.new()
    end

    # set the logger instance for output logging
    # +logger+::  an instance of a Ruby Logger to use for output
    #
    def self.logger=(logger)
      @@_logger = logger
      @@_logger.debug("Logger initialized for Tensor::Model")
      @@_logger
    end


    # get the schema definition for this model
    # +name+:: get the definition a specific field
    #
    def self.fields(name=nil)
      return (name.nil? ? @_fields : @_fields[name])
    end


    # inherit all field definitions from the parent class
    def self.inherit_fields!(*args)
      f = superclass.fields
      f.select!{|k,v| args.map(&:to_s).include?(k.to_s) } unless args.empty?

      @_fields ||= {}
      @_fields.deeper_merge!(f)

      return @_fields
    end


    # execute a query directly on this index
    # +options+::  options for query execution
    # * :type::    the document type to query for (default: autodetect)
    #
    def self.search!(body, options={}, es_options={})
      query = ({
        :size  => (options[:limit].nil? ? DEFAULT_RESULTS_LIMIT : options[:limit]),
      }).merge(body)

      return _wrap_response(:search, connection().search({
        :index => (options[:index] || self.index_name()),
        :body  => query
      }.merge(es_options)), options)
    end


    # execute a query directly on this index, return [] on error
    # +options+::  options for query execution
    # * :type::    the document type to query for (default: autodetect)
    #
    def self.search(body, options={}, es_options={})
      begin
        search!(body, options, es_options)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return []
      end
    end

    # find one or more records by ID
    # +id+::      a string or array of strings of IDs to retrieve
    # +options+::  options that dictate how to perform the query
    # * :limit::   the maximum number of documents to return
    # * :types::   an array of specific types to restrict the query to
    # * See _wrap_response for additional options
    #
    def self.find!(id, options={})
      if id.is_a?(Array)
        return _wrap_response(:search, connection().search({
          :index => self.index_name(),
          :body  => {
            :version => true,
            :size  => (options[:limit] || DEFAULT_INTERNAL_LIMIT),
            :query => {
              :ids => {
                :type   => (options[:types].nil? ? nil : [*options[:types]]),
                :values => id
              }
            }
          }
        }), options)
      else
        _wrap_response(:get, connection().get({
          :index => self.index_name(),
          :type  => (options[:types].nil? ? nil : [*options[:types]]),
          :id    => id
        }), options)
      end
    end


    def self.document_ids(query=nil, options={})
      rv = connection().search({
        :index => self.index_name(),
        :fields => ['_id'],
        :size  => (options[:limit] || 10000),
        :body => {
          :filter => (query || {
            :match_all => {}
          })
        }
      })

      rv.get('hits.hits',[]).collect{|i| i['_id'] }
    end


    # find one or more records by ID, return nil if not found
    # +id+::      a string or array of strings of IDs to retrieve
    # +options+::  options that dictate how to perform the query
    # * :limit::   the maximum number of documents to return
    # * :types::   an array of specific types to restrict the query to
    # * See _wrap_response for additional options
    #
    def self.find(id, options={})
      begin
        return find!(id, options)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return nil
      end
    end


    def self.all(options={})
      return self.search({
        :version => true,
        :query => {
          :match_all => {}
        }
      }, options, {
        :type => document_type()
      })
    end

    # create and immediately save a record
    # +attributes+:: the record data (NOTE: if attributes contains an 'id' field, it will be used instead of an autogenerated id)
    #
    def self.create(attributes, options={}, es_options={})
      rv = self.new(attributes)
      rv.save(options, es_options)
      rv
    end

    # update and immediately save a record
    # +id+::         the id of the record to update
    # +attributes+:: the record data
    #
    def self.update(id, attributes, options={}, es_options={})
      self.find!(id).update(attributes).save(options, es_options)
    end

    # determine whether a document with the given ID exists in the index
    # +id+: the id to check
    #
    def self.exists?(id)
      connection().exists({
        :index   => self.index_name(),
        :type    => self.document_type(),
        :id      => id,
        :refresh => true
      })
    end


    # delete a record without firing callbacks
    # +id+: the id to remove
    #
    def self.delete(id, es_options={})
      if exists?(id)
        connection().delete({
          :index   => self.index_name(),
          :type    => self.document_type(),
          :id      => id,
          :refresh => true
        }.merge(es_options))

        return true
      else
        return false
      end
    end


    # delete all records in this index
    #
    def self.delete_all()
      connection().delete_by_query({
        :index   => self.index_name(),
        :type    => self.document_type(),
        :body    => {
          :filter => {
            :match_all => {}
          }
        }
      })

      return (connection().count({
        :index   => self.index_name(),
        :type    => self.document_type()
      }) == 0)
    end

    # get/set the index name for this model.
    # +override+:: the index name to set (default: autodetect)
    #
    def self.index_name(override=nil)
      if override.nil?
        if @_index_name.nil?
          override = self.name.underscore
          override = (override.respond_to?(:pluralize) ? override.pluralize : override+'s')
          @_index_name = override
        end
      else
        @_index_name = override
      end

      @_index_name
    end

    # get/set the document_type for this model.
    # +override+:: the document type to set (default: autodetect)
    #
    def self.document_type(override=nil)
      if override.nil?
        @_document_type ||= self.name.gsub('::','.').underscore
      else
        @_document_type = override
      end

      @_document_type
    end


    # get/set the Elasticsearch options to be passed with all create/save operations
    # +override+:: the document type to set (default: autodetect)
    #
    def self.index_options(override=nil, &block)
      if block_given?
        @_index_options = yield
      elsif override.nil?
        @_index_options ||= {}
      else
        @_index_options = override
      end

      @_index_options
    end


    # get/set the named connection for this model from the connection pool
    # +name+::  the named connection to retrieve (default: nil)
    #
    def self.connection(name=nil)
      ConnectionPool.connection(name || :default)
    end


    # retrieve/declare explicit mappings for this model
    def self.mappings(definition=nil, options={}, &block)
      _mappings = _generate_mapping(options || {})

      if block_given?
        @_definition ||= {
          (options[:type] || :_default_) => yield
        }
      end

    # merge in an explicit definition if specified
      if @_definition.is_a?(Hash)
        _mappings.deeper_merge(@_definition.stringify_keys(), {
          :merge_hash_arrays => true
        })
      end

    # handle post-1.0 case
      if _mappings['mappings'].is_a?(Hash)
        _mappings['mappings']
      else
        return _mappings
      end
    end

    def self.all_mappings()
      mappings(nil, {
        :remote => true
      })
    end

    # retrieve/declare explicit settings for this model
    def self.settings(definition=nil, &block)
      if block_given?
        @_settings ||= yield
      elsif not definition.nil?
        @_settings ||= definition
      end

      return @_settings
    end


    # synchronize the automatic and explicit mapping on this model with elasticsearch
    def self.sync_schema(options={})
    # create the index if it doesn't exist
      unless options[:autoalias] === false
        unless connection().indices.exists_alias({
          :name => index_name()
        })
          alias_index({
            :index => index_name()
          })
        end
      end

      # straight non-aliased index creation
      #
      # connection().indices.create({
      #   :index => index_name(),
      #   :body  => {
      #     :settings => settings()
      #   }
      # })

    # update mappings
      connection().indices.put_mapping({
        :index => (options[:index] || index_name()),
        :type  => (options[:type] || document_type()),
        :body  => mappings(nil, options[:mappings])
      })
    end

   def self.alias_index(options={})
    # aliased indices
      options[:index] ||= index_name()
      index = (options[:new_index] || options[:index]+'-'+(options[:seed] || ((get_indices(options[:index]).last.split('-',2).last.to_i+1) rescue 1)).to_s)

      unless options[:create] === false
        connection().indices.create({
          :index => index,
          :body  => {
            :settings => settings(),
            :mappings => mappings(nil, options[:mappings])
          }
        })
      end

      unless options[:swap] === false
      # perform an atomic swap ensuring that the new index is the only index
      # that the alias refers to
        connection().indices.update_aliases({
          :body => {
            :actions => (((connection().indices.get_aliases({
              :index => options[:index]
            }).keys rescue []) - [index]).collect{|i|
              {
                :remove => {
                  :index => i,
                  :alias => options[:index]
                }
              }
            })+[{
              :add => {
                :index => index,
                :alias => options[:index]
              }
            }]
          }
        })
      end

      return index
    end

    def self.get_indices(prefix=nil)
      connection().indices.stats['indices'].keys.select{|i|
        i =~ Regexp.new("^#{prefix || index_name()}-[0-9]+")
      }.sort()
    end

    def self.get_closed_indices(prefix=nil)
      connection().cluster.state.get('blocks.indices',{}).keys.select{|i|
        i =~ Regexp.new("^#{prefix || index_name()}-[0-9]+")
      }.sort()
    end

    def self.get_real_index(index=nil)
      begin
        connection().indices.get_aliases({
          :index => (index || index_name())
        }).keys.sort.reverse
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return []
      end
    end

    def self.reindex(options={})
      options[:index] ||= index_name()

    # save the current referenced indices
      indices_to_cleanup = get_real_index(options[:index])

    # create the new "real" index, but don't swap the aliases yet
      new_index = alias_index({
        :index => options[:index],
        :create => true,
        :swap   => false,
        :mappings  => {
          :no_merge_existing => true
        }
      })

    # copy all records from the current index to the new index
      status = copy_index(options[:index], new_index)
      raise "Index data copy failed, leaving alias #{index_name()}->#{indices_to_cleanup.join(',')} intact" unless status['ok'] === true

    # atomically swap the indicies
      alias_index({
        :index     => options[:index],
        :create    => false,
        :swap      => true,
        :new_index => new_index
      })


    # cleanup the old indices (default: close them)
      indices_to_cleanup.each do |i|
        case (options[:cleanup] || :close).to_sym
        when :close
          connection().indices.close({
            :index => i
          })
        when :delete
          connection().indices.delete({
            :index => i
          })
        end
      end

      return new_index
    end

    def self.copy_index(source_index, dest_index, options={})
    # default is to copy everything
      options[:query] ||= {
        :filter => {
          :match_all => {}
        }
      }

    # ensure source index exists first
      return false unless connection().indices.exists({
        :index => source_index
      })

    # create dest index if it does not exist
      dest_exists = connection().indices.exists({
        :index => dest_index
      })

      if not dest_exists or dest_exists and options[:delete_if_exists] === true
        if dest_exists
          connection().indices.delete({
            :index => dest_index,
          })
        end

        connection().indices.create({
          :index => dest_index,
          :body  => {
            :settings => (connection().indices.get_settings({
              :index => source_index
            }).first.last['settings'] rescue nil),

            :mappings => (connection().indices.get_mapping({
              :index => source_index
            }).first.last rescue nil)

          }.reject{|k,v|
            v.nil?
          }
        })
      end

    # perform the search
      scroll = connection().search({
        :index       => source_index,
        :scroll      => '5m',
        :size        => 500,
        :search_type => :scan,
        :body        => options[:query]
      })

      scroll_id = scroll['_scroll_id']

      if scroll_id
        hits = scroll.get('hits.total',0)

        loop do
          results = connection().scroll({
            :scroll    => '5m',
            :scroll_id => scroll_id
          })

          break if results.get('hits.hits',[]).empty?

        # update scroll id from latest results
          scroll_id = results.get('_scroll_id')

          connection().bulk({
            :refresh => true,
            :body    => results.get('hits.hits').collect{|data|
              {
                :index => {
                  :_index => dest_index,
                  :_id    => data['_id'],
                  :_type  => data['_type'],
                  :data   => data['_source']
                }
              }
            }
          })
        end
      end

      connection().indices.stats({
        :index => dest_index
      })
    end

  private
    def self._normalize_value(value, field)
      raise "Field type is required for value #{value}" if field[:type].nil?
      type = field[:type].to_sym

    # handle arrays of things
      if field[:array] === true
      # already an array, normalize each value
        if value.is_a?(Array)
          rv = value.collect{|i|
            _normalize_type(type, i, field)
          }
        else
      # automatically wrap things in arrays if they aren't already
          rv = [_normalize_type(type, value, field)]
        end

      # compact nils out of arrays unless told otherwise
        rv = rv.compact unless field[:compact] === false

        return rv
      else
      # not an array of things, normalize scalar values
        return _normalize_type(type, value, field)
      end
    end

    def self._normalize_type(type, value, field)
      default = field[:default]

    # handle nulls up front
      if value.nil? or ['', 'null'].include?(value.to_s.downcase.strip)
        return default
      end

    # normalize value
      case type.to_sym
      when :integer
        return Integer(value) rescue default
      when :float
        return Float(value) rescue default
      when :date
        if value.is_a?(Time)
          return value
        else
          return Time.parse(value) rescue default
        end
      when :boolean
        return value if value === true or value === false

        case value.to_s.downcase
        when /t|on|1|yes|true/
          return true
        else
          return (default === true ? true : false)
        end
      when :object
        default = {} unless default.is_a?(Hash)
        return (value.is_a?(Hash) ? (value.empty? ? default : value) : default)

      when :string
        return value.to_s.strip.chomp

      else
        return default
      end

      return default
    end


    # convert the response from the Elasticsearch API into Model objects
    # or arrays of Model objects
    # Params:
    # +method+::   the API method that generated this response
    # +response+:: the API response data
    # +options+::  options that dictate how to process the response
    # * :raw::     boolean, whether to wrap the response (false) or pass it through untouched (true)
    #
    def self._wrap_response(method, response, options={})

      if options[:raw] === true
        return response
      else
        case method.to_sym
        when :get
          return nil unless response.has_key?('_source')
          return _build_instance(response)

        when :search
          return nil unless defined?(response['hits']['hits'])
          return response['hits']['hits'].collect{|i|
            i['_source'] = i['fields'] if i['_source'].nil? and not i['fields'].nil?
            next if i['_source'].nil?
            next if i['_id'][0].chr == '_'

            _build_instance(i)
          }.compact
        end
      end

      return nil
    end

    def self._build_instance(document)
      if document['_type'].nil?
        klass = self
      else
        if document['_type'].include?('::')
          parts = document['_type'].split('::')
        else
          parts = document['_type'].split('.').collect{|i| i.split('_').collect{|i| i.capitalize }.join() }
        end

        base = parts[0..-2].inject(Object){|k,i| k = k.const_get(i) }
        klass = base.const_get(parts[-1])
      end

      klass.new(document['_source'], {
        :metadata => document.reject{|k,v| k == '_source' }
      })
    end

    def self._generate_mapping(options={})
      mapping = {
        (options[:type] || :_default_).to_s => DEFAULT_MAPPING.deep_clone.deeper_merge({
          'properties' => Hash[fields().reject{|k,v|
            v.get(:skip_mapping, false)
          }.collect{|name, definition|
            definition = definition.stringify_keys()

            es_mapping = {
              'type'  => definition['type'].to_s,
              'index' => definition['index']
            }.reject{|k,v|
              v.nil?
            }

            if definition['typedefs'].is_a?(Hash)
              definition['typedefs'].each_recurse(:intermediate => true) do |k,v,p|
                if v.is_a?(Hash) and not v['type'].nil?
                  es_field = ['properties', p[0..-2].collect{|i| ['properties', i] }, p[-1]].flatten.join('.')

                  v = {
                    'type' => v.to_s
                  } unless v.is_a?(Hash)

                  es_mapping.set(es_field, v)
                end
              end
            end

            [name.to_s, es_mapping]
          }]
        })
      }

      begin
        if options[:remote] === true
          return connection().indices.get_mapping({
            :index => index_name()
          }).get(get_real_index().first,{}).deeper_merge!(mapping)
        else
          return mapping
        end
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
        return mapping
      end
    end
  end
end
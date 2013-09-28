require 'deep_merge/rails_compat'
require 'elasticsearch'
require 'active_model'

begin
  require 'active_support/inflector'
rescue LoadError
  nil
end

module Tensor
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
        connect({}, name)
      end
    end
  end

  class Model
    include ::ActiveModel::Model
    extend  ::ActiveModel::Callbacks

    define_model_callbacks :save, :create, :destroy, :update

    attr_accessor :id
    attr_accessor :type
    attr_reader   :_metadata
    attr_accessor :attributes

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

      @_index_name = self.class.index_name()
      @_document_type = self.class.document_type()
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

          @attributes[key] = value

        # hack to temporarily disable "dirty" flagging in attr setter
          @_permaclean = true
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
    def save(options={})
      run_callbacks :save do
        result = self.class.connection().index({
          :index => @_index_name,
          :type  => @_document_type,
          :id    => self.id,
          :body  => self.to_indexed_hash()
        })

      # failed save has failed
        return false unless result['ok'] === true

        self.id = result['_id']


      # unless otherwise specified, make another query to retrieve the object we just saved and update our data
        unless options[:reload] === false
          self.from_hash(self.class.find(self.id).to_hash)
        end
      end

      return self
    end


    def delete()

    end

    def query(body, options={})
      self.class.query(body, options)
    end

    def keys(name=nil)
      self.class.keys(name)
    end

    def dirty?()
      return @_dirty
    end

    def to_indexed_hash()
      rv = to_hash()

    # furthermore, always remove id/type from the output
      %w{id _id type _type}.each do |i|
        rv.delete(i)
      end

      rv = rv.each_recurse! do |k,v,p|
        if v.is_a?(Time)
          v.strftime('%Y-%m-%dT%H:%M:%S%z')
        else
          v
        end
      end

      return rv
    end

    private
      def _normalize_value(value, field)
        type = (field[:type] || :string).to_sym

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

      def _normalize_type(type, value, field)
        default = field[:default]

      # normalize value
        case type.to_sym
        when :integer
          rv = Integer(value) rescue default
        when :float
          rv = Float(value) rescue default
        when :date
          rv = Time.parse(value) rescue default
        when :boolean
          rv = value if value === true or value === false
          case value.to_s.downcase
          when /t|on|1|yes|true/
            rv = true
          else
            rv = (default === true ? true : false)
          end
        when :object
          rv = (value.is_a?(Hash) ? (value.empty? ? default : value) : default)

        when :string
          rv = value.to_s
          rv = default if rv.empty?
        else
          rv = default
        end

        return rv
      end



  ################################################################################
  # class methods
  #
    class<<self
      DEFAULT_INTERNAL_LIMIT = 1000
      DEFAULT_RESULTS_LIMIT  = 10000
      DEFAULT_MAPPING = {
        'properties' => {
          '_type' => {
            'type' => 'string'
          }
        }
      }

      # define a valid field name, including type and persistence options
      # Params:
      # +name+:: the name of the field
      # +type+:: the data type of the field (can be :string, :integer, :float, :boolean, :date, :hash; default is :string)
      # +options+::  options for building the field
      # * :array::   boolean, whether to store the field as an array of +type+ values (true) or not (false)
      #
      def key(name, type=:string, options={})
        @_properties ||= {}
        name = name.to_sym
        raise "Duplicate key definition #{name}" if @_properties.has_key?(name)

      # register the key definition
        @_properties[name] = {
          :type => type.to_s.downcase.to_sym
        }.merge(options)


      # define getter
        define_method(name.to_s) do
          if instance_variables.include?("@#{name}".to_sym)
            instance_variable_get("@#{name}")
          else
            _normalize_value(nil, self.class.keys(name))
          end
        end

      # define setter
        define_method("#{name}=") do |value|
        # normalize the value according to type/default rules for this field
          value = _normalize_value(value, self.class.keys(name))

          instance_variable_set("@#{name}", value)
          @attributes[name.to_s] = value

        # flag instance as dirty unless we've stopped doing that because it's not cool anymore...
          @_dirty = true unless @_permaclean

        # return what we just set
          send(name)
        end

      end

      # get the schema definition for this model
      # +name+:: get the definition a specific field
      #
      def keys(name=nil)
        rv = (name.nil? ? @_properties : @_properties[name])
        return (rv.nil? ? {} : rv)
      end


      # execute a query directly on this index
      # +options+::  options for query execution
      # * :type::    the document type to query for (default: autodetect)
      #
      def search!(body, options={})
        return _wrap_response(:search, connection().search({
          :index => (options[:index] || self.index_name()),
          :type  => (options[:type] || self.document_type()),
          :body  => ({
            :size  => (options[:limit].nil? ? DEFAULT_RESULTS_LIMIT : options[:limit]),
          }).merge(body)
        }), options)
      end


      # execute a query directly on this index, return [] on error
      # +options+::  options for query execution
      # * :type::    the document type to query for (default: autodetect)
      #
      def search(body, options={})
        begin
          search!(body, options)
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
      def find!(id, options={})
        if id.is_a?(Array)
          return _wrap_response(:search, connection().search({
            :index => self.index_name(),
            :body  => {
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

      # find one or more records by ID, return nil if not found
      # +id+::      a string or array of strings of IDs to retrieve
      # +options+::  options that dictate how to perform the query
      # * :limit::   the maximum number of documents to return
      # * :types::   an array of specific types to restrict the query to
      # * See _wrap_response for additional options
      #
      def find(id, options={})
        begin
          return find!(id, options)
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          return nil
        end
      end


      def all(options={})
        return self.search({
          :query => {
            :match_all => {}
          }
        }, options)
      end

      # create and immediately save a record
      # +attributes+:: the record data (NOTE: if attributes contains an 'id' field, it will be used instead of an autogenerated id)
      #
      def create(attributes)
        self.new(attributes).save()
      end

      # update and immediately save a record
      # +id+::         the id of the record to update
      # +attributes+:: the record data
      #
      def update(id, attributes)
        self.find!(id).update(attributes)
      end

      # get/set the index name for this model.
      # +override+:: the index name to set (default: autodetect)
      #
      def index_name(override=nil)
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
      def document_type(override=nil)
        if override.nil?
          @_document_type ||= self.name.underscore
        else
          @_document_type = override
        end

        @_document_type
      end

      # get/set the named connection for this model from the connection pool
      # +name+::  the named connection to retrieve (default: nil)
      #
      def connection(name=nil)
        ConnectionPool.connection(name || :default)
      end


      # retrieve/declare explicit mappings for this model
      def mappings(definition=nil, &block)
        @_mappings ||= _generate_mapping()

        if block_given?
          definition = {
            document_type() => yield
          }
        end

      # merge in an explicit definition if specified
        if definition.is_a?(Hash)
          @_mappings.deeper_merge(definition.stringify_keys(), {
            :merge_hash_arrays => true
          })
        end

        return @_mappings
      end

      # retrieve/declare explicit settings for this model
      def settings(definition=nil, &block)
        if block_given?
          @_settings ||= yield
        elsif not definition.nil?
          @_settings ||= definition
        end

        return @_settings
      end


      # synchronize the automatic and explicit mapping on this model with elasticsearch
      def sync_schema(options={})
      # create the index if it doesn't exist
        unless connection().indices.exists({
          :index => index_name()
        })
          connection().indices.create({
            :index => index_name(),
            :body  => {
              :settings => settings()
            }
          })
        end

      # update mappings
        connection().indices.put_mapping({
          :index => index_name(),
          :type  => document_type(),
          :body  => mappings()
        })
      end

    private
      # convert the response from the Elasticsearch API into Model objects
      # or arrays of Model objects
      # Params:
      # +method+::   the API method that generated this response
      # +response+:: the API response data
      # +options+::  options that dictate how to process the response
      # * :raw::     boolean, whether to wrap the response (false) or pass it through untouched (true)
      #
      def _wrap_response(method, response, options={})
#pp response

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
              next unless defined?(i['_source'])
              next if i['_id'][0].chr == '_'

              _build_instance(i)
            }.compact
          end
        end

        return nil
      end

      def _build_instance(document)
        if document['_type'].nil?
          klass = self
        else
          klass = Kernel.const_get(document['_type'].split('/').collect{|i|
            i.split('_').collect{|i| i.capitalize }.join()
          }.join('::'))
        end

        klass.new(document['_source'], {
          :metadata => document.reject{|k,v| k == '_source' }
        })
      end

      def _generate_mapping(options={})
        {
          (options[:type] || document_type()) => DEFAULT_MAPPING.deeper_merge({
            'properties' => Hash[keys().collect{|name, definition|
              definition = definition.stringify_keys()

              [name.to_s, {
                'type' => definition['type'].to_s
              }]
            }]
          })
        }
      end
    end

    alias_method  :to_hash, :attributes
  end
end
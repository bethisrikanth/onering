require 'mongo_mapper'
require 'tire'
require 'active_record'
require 'pp'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    module Utils

    # serialize to a Hash
      def to_h
        serializable_hash.reject{|k,v|
          ['_type'].include?(k)
        }
      end

      def to_h!
        serializable_hash
      end

    # populate the document from a Hash
      def from_h(hash, merge=true, autotype=false)
        raise "Cannot populate model: expected Hash, got #{hash.class.name}" unless hash.is_a?(Hash)

        if merge
        # build list of paths to fully replace
          unset_keys = Hash[hash.coalesce(nil, nil, '.').select{|k,v|
            k.include?('@')
          }].keys.collect{|k|
            k = k.split('.')
            i = k.index{|i| i[0].chr == '@' }

            (i ? k.first(i+1).join('.') : nil)
          }.compact.uniq

          newhash = to_h
        # delete existing keys that are to be replaced
        # rename incoming keys to exclude symbols
          unset_keys.each do |key|
            newhash.unset(key.delete('@'))
            hash.rekey(key, key.delete('@'))
          end

          newhash = newhash.deeper_merge!(hash, {:merge_hash_arrays => true})
        else
          newhash = hash
        end

      # automatically convert fields ending with _at or _on to Time
        newhash.each_recurse! do |k,v,p|
          case k
          when /_(?:at|on)$/i
            if v == 'now'
              Time.now
            else
              (Time.parse(v) rescue v)
            end
          else
            v
          end
        end

        newhash.each do |k,v|
          send("#{k}=", v) rescue nil
        end

        self
      end

    # populate the document from a JSON string
      def from_json(json, merge=true, autotype=false)
        json = JSON.parse(json) if json.is_a?(String)
        json = [json] if json.is_a?(Hash)

        if json
          json.each do |j|
            from_h(j, merge, autotype)
          end
        end

        self
      end

    # save, but throw an error if not valid
      def safe_save
        save({
          :safe => true
        }) or raise Errors::ValidationError, errors.collect{|k,v| v }.join("; ")
      end

    # provide a difference between two documents (useful for audit history)
      def -(other)
        diff = (serializable_hash - other.serializable_hash)
      end


      alias_method :to_hash, :to_h
    end

    class Base
      include MongoMapper::Document
      include Utils

      class<<self
        alias :_mongo_find :find
        attr_accessor :query_limit
        attr_accessor :query_offset

        def find(id)
          q = self._mongo_find(id)
          q.limit(query_limit) if query_limit
          q.skip(query_offset) if query_offset
          q
        end

        def find_or_create(ids, init={})
          rv = find(ids)

          if not rv
            [*ids].each do |id|
              i = new({'id' => id})

              i.safe_save
            end

            rv = find(ids)
          end

          rv
        end

        def list(field, query=nil)
          rv = self.collection.distinct(field, query).compact.sort
          rv = rv[(query_offset.to_i)..(query_offset.to_i + (query_limit || rv.length))]
          rv
        end
      end
    end

    module Taggable
      def tag(value)
        [*value].each do |v|
          add_to_set({:tags => v})
        end
        safe_save
        self
      end
    end


    class Elasticsearch
      require 'assets/lib/elasticsearch_urlquery_parser'

      DEFAULT_MAX_RESULTS = 10000

      include ::Tire::Model::Callbacks
      include ::Tire::Model::Persistence

      define_model_callbacks :create, :update, :validation, :destroy

      alias_method :to_h,             :to_hash

      before_save            :_update_timestamps

      def _update_timestamps
        if self.respond_to?('updated_at')
          self.updated_at = Time.now
        end
      end

      def from_h(hash)
        hash.compact.each do |key, values|
          self.send("#{key}=", values)
        end

        self
      end

      def method_missing(name, *args)
        if name == :_id=
          false
        else
          super
        end
      end

      class<<self
        include_root_in_json = false

        alias_method :_tire_property,   :property
        alias_method :_tire_properties, :properties
        alias_method :_tire_all,        :all

        def property(name, options={})
          _tire_property(name, {
            :index => :analyzed
          }.merge(options))
        end

        def to_elasticsearch_query(query, options={})
          @@_parser ||= App::Helpers::ElasticsearchUrlqueryParser.new()
          rv = @@_parser.parse(query).to_elasticsearch_query({
            :fields => options[:fields]
          })

#puts MultiJson.dump(rv)

          rv
        end

        def get(field, default=nil)
          return self.to_hash.get(self.resolve_field(field), default)
        end

        def urlquery(query, options={})
          q = ({
            :size => DEFAULT_MAX_RESULTS
          }.merge(self.to_elasticsearch_query(query, options)))

          collection = Tire.search(self.index_name(), q)

          collection.options[:load] = (options[:load].nil? ? true : options[:load])
          collection.results
        end

        def where(query, options={})
          collection = Tire.search(self.index_name(), {
            :size        => (options[:size] || DEFAULT_MAX_RESULTS),
            :fields      => options[:fields]
          }.compact.merge(query))

          collection.options[:load] = (options[:load].nil? ? true : options[:load])
          collection.results
        end

        def list(field, query=nil)
          field = self.resolve_field(field)

          if not query.nil?
            filter = self.to_elasticsearch_query(query)
          end

          results = self.where({
            :filter => filter,
            :facets => {
              field => {
                :terms => {
                  :field => field
                }
              }
            }
          }.compact, {
            :size   => 0,
            :load   => false
          })


          facet = results.facets[field]
          return [] if facet.nil?

          return facet.get(:terms,[]).collect{|i|
            i.get(:term)
          }.compact.sort.uniq

        end

      # summarize
      #   this method provides arbitrary-depth aggregate rollups of a MongoDB
      #   collection, using the MongoDB Aggregation Framework (mongodb 2.1+)
      #
      #   group_by:   the top-level field to group by
      #   properties: additional fields to drill down into
      #   query:      a query Hash to filter the collection by
      #               (defaults to a summary of the whole collection)
      #
        def summarize(group_by, properties=[], query=nil, options={})
          fields = ([group_by]+[*properties]).compact.collect{|field|
            self.resolve_field(field)
          }

          if query.nil?
            query = self.where({
              :fields => fields,
              :query => {
                :match_all => {}
              }
            })
          else
            query = self.urlquery(query, {
              :fields => fields
            })
          end

          results = query.collect{|i|
            i.to_hash
          }

          results.count_distinct(fields)
        end

        def from_h(hash)
          hash.each do |key, values|
            self.send("#{key}=", values)
          end

          self
        end

        def resolve_field(field)
          return '_id' if field == 'id'
          return field if (@_field_prefix_skip || []).include?(field)
          return field if field.to_s.empty? or @_field_prefix.to_s.empty?
          return @_field_prefix+'.'+field
        end


      # dsl configuration options
        def field_prefix(name=nil)
          return @_field_prefix if name.nil?
          @_field_prefix = name.to_s
          @_field_prefix_skip ||= self.properties.reject{|i| i.to_s == name.to_s }
        end

        def field_prefix_skip(list=nil)
          return @_field_prefix_skip if list.nil?
          @_field_prefix_skip = [*list]
        end

        def defaults(type=:_default_, &block)
          if block_given?
            index.create({
              :mappings => {
                type => yield
              }
            })
          end
        end
      end
    end
  end
end

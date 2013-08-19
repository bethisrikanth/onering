require 'mongo_mapper'
require 'tire'
require 'pp'

Tire.configure { logger 'elasticsearch.log' }

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

      DEFAULT_MAX_RESULTS     = 10000
      DEFAULT_MAX_API_RESULTS = 25

      include ::Tire::Model::Callbacks
      include ::Tire::Model::Persistence

      define_model_callbacks :create, :update, :validation, :destroy

      #alias_method :to_h,             :to_hash
      #alias_method :_original_find,   :find

      before_save            :_update_timestamps

      def _update_timestamps
        if self.respond_to?('updated_at')
          self.updated_at = Time.now
        end
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
        newhash = newhash.each_recurse do |k,v,p|
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
          self.send("#{k}=", v) rescue nil
        end

        return self
      end

    # populate the document from a JSON string
      def from_json(json, merge=true, autotype=false)
        json = MultiJson.load(json) if json.is_a?(String)
        json = [json] if json.is_a?(Hash)

        if json
          json.each do |j|
            from_h(j, merge, autotype)
          end
        end

        return self
      end


      def get(field, default=nil)
        return to_hash.get(self.class.resolve_field(field), default)
      end

      def set(field, value)
        return from_h(to_hash.set(self.class.resolve_field(field), value))
      end

      def unset(field)
        return set(field, nil)
      end

      def push(field, values, coerce=:auto)
        values = [*values]

        current = [*get(field)].compact
        values.each do |v|
          current.push_uniq(v.convert_to(coerce))
        end

        return set(field, current)
      end

      def pop(field, empty=nil)
        current = [*get(field)].compact

        rv = current.pop()
        current = nil if current.empty?

        set(field, current)

        return empty if rv.nil?
        return rv
      end

      class<<self
        include_root_in_json = false

        alias_method :_tire_property,   :property
        alias_method :_tire_properties, :properties
        alias_method :_tire_all,        :all


        def configure(options={})
          return false if options.empty?

          Tire.configure do
            url(options.get(:url)) if options.get(:url)
          end

          return true
        end

        def property(name, options={})
          _tire_property(name, {
            :index => :analyzed
          }.merge(options))
        end

        def to_elasticsearch_query(query, options={})
          @@_parser ||= App::Helpers::ElasticsearchUrlqueryParser.new()
          rv = @@_parser.parse(query).to_elasticsearch_query({
            :prefix => self.field_prefix(),
            :fields => self._tire_properties
          })

#puts MultiJson.dump(rv)

          rv
        end

        def urlquery(query, options={})
          raw = options.delete(:raw)
          load = options.delete(:load)
          load = true if load.nil?

          options[:fields].collect!{|i|
            self.resolve_field(i)
          } unless options[:fields].nil?

          query = {
            :size   => DEFAULT_MAX_RESULTS,
            :filter => self.to_elasticsearch_query(query),
            :fields => (self._tire_properties - [self.field_prefix()])
          }.deeper_merge!(options, {
            :merge_hash_arrays => true
          })

#puts MultiJson.dump(query)

          collection = Tire.search(self.index_name(), query)

          collection.options[:load] = load

          return collection.results unless raw.nil?
          return collection.results.to_a
        end

        def where(query)
          load = query.delete(:load)
          load = true if load.nil?

          collection = Tire.search(self.index_name(), {
            :size        => DEFAULT_MAX_RESULTS
          }.compact.merge(query))

          collection.options[:load] = load
          return collection.results
        end

        def id(ids)
          rv = self.where({
            :filter => {
              :ids => {
                :values => [*ids]
              }
            }
          })

          return rv if ids.is_a?(Array)
          return rv.first
        end

        def list(field, query=nil)
          field = self.resolve_field(field)

          if not query.nil?
            filter = self.to_elasticsearch_query(query)
          end

          results = self.where({
            :size   => 0,
            :load   => false,
            :filter => filter,
            :facets => {
              :counts => {
                :terms => {
                  :field => field
                }
              }
            }
          }.compact)

          facet = results.facets.get(:counts)
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
          rv = []

          fields = ([group_by]+[*properties]).compact.collect{|field|
            self.resolve_field(field)
          }.reverse

        # pop current field off the stack
          current_field = fields.pop()

        # perform query, only return facets (no documents)
          results = self.where({
            :size   => 0,
            :load   => false,
            :facets => {
              :counts => {
                :facet_filter => (query.nil? ? nil : self.to_elasticsearch_query(query)),
                :terms => {
                  :field => current_field
                }
              }.compact
            }
          })

        # if we got anything...
          unless results.facets.nil?
            results.facets.get('counts.terms',[]).each do |facet|
              rv << {
                :id       => facet['term'],
                :field    => self.unresolve_field(current_field),
                :count    => facet['count'],
                :children => (fields.empty? ? nil :
                # we need to go deeper...
                  self.summarize(fields[0], fields[1..-1], [query, "#{self.unresolve_field(current_field)}/#{facet['term']}"].compact.join('/'))
                )
              }.compact
            end

          # add in empty results as nulls
            if results.facets.get('counts.missing',0) > 0
              rv << {
                :id       => nil,
                :field    => self.unresolve_field(current_field),
                :count    => results.facets.get('counts.missing'),
                :children => (fields.empty? ? nil :
                # we need to go deeper...
                  self.summarize(fields[0], fields[1..-1], [query, "#{self.unresolve_field(current_field)}/null"].compact.join('/'))
                )
              }
            end
          end

          return rv
        end

        def resolve_field(field)
          return '_id' if field == 'id'
          return field if (@_field_prefix_skip || []).include?(field)
          return field if field.to_s.empty? or @_field_prefix.to_s.empty?
          return field if field =~ Regexp.new("^#{@_field_prefix}\.")
          return @_field_prefix.to_s+'.'+field.to_s
        end

        def unresolve_field(field)
          field.to_s.gsub(Regexp.new("^#{@_field_prefix}\."), '')
        end


      # dsl configuration options
        def field_prefix(name=nil)
          return @_field_prefix.to_s if name.nil?
          @_field_prefix = name.to_s
          @_field_prefix_skip ||= self.properties.reject{|i| i.to_s == name.to_s }
        end

        def field_prefix_skip(list=nil)
          return @_field_prefix_skip if list.nil?
          @_field_prefix_skip = [*list].map(&:to_s)
        end

        def defaults(type=nil, &block)
          if block_given?
            @defaults = yield
            index.put_mapping(self.name.downcase, @defaults)
          else
            @defaults
          end
        end

        def inherited(subclass)
          @@_implementers ||= Set.new()
          @@_implementers << subclass
        end

        def implementers
          @@_implementers
        end
      end
    end
  end
end

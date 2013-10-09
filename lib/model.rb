require 'tensor'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

    # module Utils

    # # serialize to a Hash
    #   def to_h
    #     serializable_hash.reject{|k,v|
    #       ['_type'].include?(k)
    #     }
    #   end

    #   def to_h!
    #     serializable_hash
    #   end

    # # populate the document from a Hash
    #   def from_h(hash, merge=true, autotype=false)
    #     raise "Cannot populate model: expected Hash, got #{hash.class.name}" unless hash.is_a?(Hash)

    #     if merge
    #     # build list of paths to fully replace
    #       unset_keys = Hash[hash.coalesce(nil, nil, '.').select{|k,v|
    #         k.include?('@')
    #       }].keys.collect{|k|
    #         k = k.split('.')
    #         i = k.index{|i| i[0].chr == '@' }

    #         (i ? k.first(i+1).join('.') : nil)
    #       }.compact.uniq

    #       newhash = to_h
    #     # delete existing keys that are to be replaced
    #     # rename incoming keys to exclude symbols
    #       unset_keys.each do |key|
    #         newhash.unset(key.delete('@'))
    #         hash.rekey(key, key.delete('@'))
    #       end

    #       newhash = newhash.deeper_merge!(hash, {:merge_hash_arrays => true})
    #     else
    #       newhash = hash
    #     end

    #   # automatically convert fields ending with _at or _on to Time
    #     newhash.each_recurse! do |k,v,p|
    #       case k
    #       when /_(?:at|on)$/i
    #         if v == 'now'
    #           Time.now
    #         else
    #           (Time.parse(v) rescue v)
    #         end
    #       else
    #         v
    #       end
    #     end

    #     newhash.each do |k,v|
    #       send("#{k}=", v) rescue nil
    #     end

    #     self
    #   end

    # # populate the document from a JSON string
    #   def from_json(json, merge=true, autotype=false)
    #     json = JSON.parse(json) if json.is_a?(String)
    #     json = [json] if json.is_a?(Hash)

    #     if json
    #       json.each do |j|
    #         from_h(j, merge, autotype)
    #       end
    #     end

    #     self
    #   end

    # # save, but throw an error if not valid
    #   def safe_save
    #     save({
    #       :safe => true
    #     }) or raise Errors::ValidationError, errors.collect{|k,v| v }.join("; ")
    #   end

    # # provide a difference between two documents (useful for audit history)
    #   def -(other)
    #     diff = (serializable_hash - other.serializable_hash)
    #   end


    #   alias_method :to_hash, :to_h
    # end

    # class Base
    #   include MongoMapper::Document
    #   include Utils

    #   class<<self
    #     alias :_mongo_find :find
    #     attr_accessor :query_limit
    #     attr_accessor :query_offset

    #     def find(id)
    #       q = self._mongo_find(id)
    #       q.limit(query_limit) if query_limit
    #       q.skip(query_offset) if query_offset
    #       q
    #     end

    #     def find_or_create(ids, init={})
    #       rv = find(ids)

    #       if not rv
    #         [*ids].each do |id|
    #           i = new({'id' => id})

    #           i.safe_save
    #         end

    #         rv = find(ids)
    #       end

    #       rv
    #     end

    #     def list(field, query=nil)
    #       rv = self.collection.distinct(field, query).compact.sort
    #       rv = rv[(query_offset.to_i)..(query_offset.to_i + (query_limit || rv.length))]
    #       rv
    #     end
    #   end
    # end

    # module Taggable
    #   def tag(value)
    #     [*value].each do |v|
    #       add_to_set({:tags => v})
    #     end
    #     safe_save
    #     self
    #   end
    # end


    class Elasticsearch < Tensor::Model
      require 'assets/lib/elasticsearch_urlquery_parser'

      DEFAULT_MAX_FACETS      = 100
      DEFAULT_MAX_API_RESULTS = 25

      before_save            :_update_timestamps

    # set updated_at timestamp on save
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

          newhash = to_hash
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

        self.from_hash(newhash)

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
          if coerce.nil? or coerce == :none
            current.push_uniq(v)
          else
            current.push_uniq(v.convert_to(coerce))
          end
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
        def configure(options={})
          options = options.symbolize_keys()

          if options[:log].nil? or options[:log] === false
            options[:log]    = false
            options[:logger] = nil

          elsif options[:logger].is_a?(String)
            case options[:logger].upcase
            when 'STDOUT'
              options[:logger] = Logger.new(STDOUT)
            when 'STDERR'
              options[:logger] = Logger.new(STDERR)
            else
              options[:logger] = Logger.new(options[:logger])
            end
          end

          Tensor::ConnectionPool.connect(options)
        end

        def to_elasticsearch_query(query, options={})
          return nil if query == 'null'

          @_parser ||= App::Helpers::ElasticsearchUrlqueryParser.new()

          rv = @_parser.parse(query).to_elasticsearch_query({
            :prefix => self.field_prefix(),
            :fields => self.fields.keys()
          })

#puts MultiJson.dump(rv)

          rv
        end

        def urlquery(query, query_options={}, tensor_options={})
          query_options[:fields].collect!{|i|
            self.resolve_field(i)
          } unless query_options[:fields].nil?

          query = {
            :filter => self.to_elasticsearch_query(query),
            :fields => (self.fields.keys.collect{|i| i.to_s })
          }.deeper_merge!(query_options, {
            :merge_hash_arrays => true
          })

          return self.search(query, tensor_options)
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
          results = self.search({
            :facets => {
              :counts => {
                :facet_filter => (query.nil? ? nil : self.to_elasticsearch_query(query)),
                :terms => {
                  :field => current_field,
                  :size  => (options[:limit].nil? ? DEFAULT_MAX_FACETS : options[:limit])
                }
              }.compact
            }
          }, {
            :limit => 0,
            :raw   => true
          })

        # if we got anything...
          unless results.get('facets.counts.terms').nil?
            results.get('facets.counts.terms', []).each do |facet|
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
            if results.get('facets.counts.missing', 0) > 0
              rv << {
                :id       => nil,
                :field    => self.unresolve_field(current_field),
                :count    => results.get('facets.counts.missing'),
                :children => (fields.empty? ? nil :
                # we need to go deeper...
                  self.summarize(fields[0], fields[1..-1], [query, "#{self.unresolve_field(current_field)}/null"].compact.join('/'))
                )
              }
            end
          end

          return rv
        end

        def list(field, query=nil)
          field = [*field]

          summary = summarize(field.first, field[1..-1].reverse(), query, {
            :limit => 10000
          })

          if field.length == 1
            return summary.collect{|i| i[:id] }.compact
          else
            def get_ids(facets, rollup=nil)
              rv = []

              facets.each do |facet|

                if facet[:children].is_a?(Array)
                  if rollup.nil?
                    rv += get_ids(facet[:children], [facet[:id]])
                  else
                    rv += get_ids(facet[:children], rollup.product([facet[:id]]))
                  end
                else
                  if rollup.nil?
                    rv << [facet[:id]]
                  else
                    rv << rollup.product([facet[:id]])
                  end
                end
              end

              return rv
            end

            return get_ids(summary).map(&:flatten)
          end
        end

        def resolve_field(field)
          field = field.to_s

          return 'id' if field == 'id'
          return field if (@_field_prefix_skip || []).include?(field)
          return field if field.to_s.empty? or @_field_prefix.to_s.empty?
          return field if field =~ Regexp.new("^#{@_field_prefix}\.")
          return @_field_prefix.to_s+'.'+field
        end

        def unresolve_field(field)
          field.to_s.gsub(Regexp.new("^#{@_field_prefix}\."), '')
        end


      # dsl configuration options
        def field_prefix(name=nil)
          return @_field_prefix.to_s if name.nil?
          @_field_prefix = name.to_s
          @_field_prefix_skip ||= self.fields.keys.reject{|i| i.to_s == name.to_s }.map(&:to_s)
        end

        def field_prefix_skip(list=nil)
          return @_field_prefix_skip if list.nil?
          @_field_prefix_skip = [*list].map(&:to_s)
        end

        def inherited(subclass)
          @@_implementers ||= Set.new()
          @@_implementers << subclass
        end

        def implementers()
          @@_implementers
        end

        def sync_schemata()
          models = Hash[implementers.to_a.collect{|i| [i.index_name, i] }]

          models.each do |index, model|
            model.sync_schema()
          end
        end
      end
    end
  end
end

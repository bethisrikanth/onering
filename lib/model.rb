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

require 'tensor'

module App
  module Model
    module Errors
      class ValidationError < Exception; end
    end

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
        newhash = newhash.each_recurse do |k,v,p,dhm|
          case k
          when /_(?:at|on)$/i
            if v == 'now'
              dhm.set(p, Time.now)
            else
              dhm.set(p, (Time.parse(v) rescue v))
            end
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

          Onering::Logger.info("Connection to Elasticsearch at #{(options.get(:hosts) || ['localhost:9200']).join(',')}")
          Tensor::ConnectionPool.connect(options)
        end

        def to_elasticsearch_query(query, options={})
          return nil if query == 'null'

        #
        # HACKS: Query pre-processor for searching on multi-fields
        #
        # What is this?
        #  It deconstructs the urlquery string and adds a second field to every field
        #  being searched for.  So for example:
        #    I search for:   mac/abc123
        #    This yields:    mac|mac._analyzed/abc123
        #
        # Why am I doing this?
        #   To support multi-fields in ES that store both the analyzed and non-analyzed
        #   version of a field.  In that case we have a situation where we want to
        #   query on one part of the field but display another part.
        #
        #   Since we're generating queries in a highly generic manner, and because
        #   not every field will have this multi-field property, the kludgy way around
        #   it is to just throw both cases into an OR and call it a day.
        #
        #   I'm also certain that there is a way to do this directly in ES without said hack,
        #   but I'm only one person, the documentation can only take me so far, and the
        #   training costs ~$~$~mad billz~$~$~ that *someone* doesn't want to spend...
        #        
        #   I welcome an alternate approach. PM me: gary@outbrain.com a/s/l
        #
          query = query.split('/').collect.with_index{|x,i|
            if i.even?
                x.split('|').collect{|j|
                # turn the current field into a path for extracting the ES type of the field
                  mapping_path = (self.resolve_field(j).split('.').collect{|i| ['properties', i] }.flatten + ['type']).join('.')

                # attempt to get the type for this field
                  mapping_type = self.all_mappings[self.document_type].get(mapping_path)

                # field had no type, attempt to refresh the mapping cache and try again
                  if mapping_type.nil?
                    mapping_type = self.cache_mappings[self.document_type].get(mapping_path)
                  end

                # only add the multifield suffix for actual multi_fields
                  if mapping_type == 'multi_field'
                    [j, j+'.'+App::Config.get('database.options.querying.multifield_suffix', '_analyzed')]
                  else
                    [j]
                  end
                }.flatten.join('|')
            else
              x
            end
          }.join('/')

          @_parser ||= App::Helpers::ElasticsearchUrlqueryParser.new()

          rv = @_parser.parse(query).to_elasticsearch_query({
            :prefix         => self.field_prefix(),
            :fields         => self.fields.keys(),
            :value_analyzer => (self.method(:analyze) rescue nil)
          })

          rv
        end

        def urlquery(query, query_options={}, tensor_options={})
          query = {
            :filter => self.to_elasticsearch_query(query),
            :fields => (self.fields.keys.collect{|i| i.to_s }),
          }.deeper_merge!(query_options, {
            :merge_hash_arrays => true
          })

          unless query_options[:fields].nil?
            query[:fields] = query_options[:fields].collect{|i|
              self.resolve_field(i)
            }
          end

          return self.search(query, tensor_options)
        end

        def ids(urlquery=nil)
          urlquery = self.to_elasticsearch_query(urlquery) unless urlquery.nil?
          document_ids(urlquery)
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
                },
                :global => true
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
          field = [*field].collect{|i| resolve_field(i) }
          rows = []

          es_query = {
            :size    => Tensor::Model::DEFAULT_RESULTS_LIMIT,
            :fields  => field
          }

        # query all docuents
          if query.nil?
            results = search(es_query.merge({
              :version => true,
              :query => {
                :match_all => {}
              }
            }), {
              :raw => true
            })
          else
            results = urlquery(query, es_query, {
              :raw => true
            })

          end

          results = {} if results.empty?

          results.get('hits.hits', []).each do |hit|
            column = []

            field.each do |f|
              case f
              when 'id'
                column << hit['_id']
              else
                value = (hit['fields'][f] rescue nil)

                if value.respond_to?(:empty?) and value.empty?
                  value = nil
                end

                column << value
              end
            end

            rows << column
          end

          if field.length == 1
            rows = rows.flatten
          end

          rows.uniq
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
          @_implementers ||= Set.new()
          @_implementers << subclass
        end

        def implementers()
          @_implementers
        end

        def sync_schemata()
          models = Hash[implementers.to_a.collect{|i| [i.index_name, i] }]

          models.each do |index, model|
            model.sync_schema()
          end
        end
      end


      def self.status()
        rv = (self.connection().info().symbolize_keys() rescue {
          :ok => false
        })

        rv[:type] = :elasticsearch

        rv
      end

      def self.cluster_status()
        rv = self.connection().cluster().health().symbolize_keys() rescue {
          :status => 'red'
        }
      end
    end
  end
end

class String
  def to_elasticsearch_query()
    App::Model::Elasticsearch.to_elasticsearch_query(self)
  end
end

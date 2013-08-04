require 'babel_bridge'

module App
  module Helpers
    class ElasticsearchUrlqueryParser < BabelBridge::Parser
      TOP_LEVEL_FIELDS = ['id', 'parent_id', 'name', 'tags', 'aliases', 'status', 'updated_at', 'created_at', 'collected_at']
      DEFAULT_FIELD_PREFIX='properties'

    # process the whole query
      rule :es, many(:pair, :pairer) do
        def to_elasticsearch_query(options={})
          rv = {
            :filter => {
              :and => pair.collect{|e|
                e.to_elasticsearch_query
              }.flatten
            }
          }

        # return only top-level + named fields
          rv[:fields] = TOP_LEVEL_FIELDS+[*options[:fields]] if options[:fields]

          return rv
        end
      end

    # process pairs of field/[value] parameters
      rule :pair, many(:field, :fieldop_or), :pairer?, :values? do
        def to_elasticsearch_query()

          return ({
            :or => field.collect{|f|
              if values.to_a.empty?
                f.to_elasticsearch_query(nil)
              else
                values.to_a.collect{|v|
                  f.to_elasticsearch_query(v)
                }
              end
            }.flatten
          })
        end
      end

    # process field name, modifiers, and prefilters
      rule :field, :field_modifier?, :field_name_pre, :field_prefilter?, :field_name_post? do
        def translate_field(field, prefix)
          case field
          when 'id'
            return "_#{field}"
          when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$")
            return field
          else
            return "#{prefix}.#{field}"
          end
        end

        def to_elasticsearch_query(value=nil)
          fname_pre = translate_field(field_name_pre.to_s, DEFAULT_FIELD_PREFIX)
          fname = fname_pre + field_name_post.to_s
          rv = nil

        # no value
          if value.empty?
          # check for unary modifiers
            if field_modifier.nil?
              rv = { :exists => {:field => fname} }
            else
              case field_modifier.get_coercer.to_sym
              when :absent
                rv = {
                  :not => { :exists => {:field => fname} }
                }
              end
            end
          else
            rv = value.to_elasticsearch_query(fname, field_modifier.nil? ? (fname =~ /_(?:at|or)$/i ? :date : nil) : field_modifier.get_coercer)
          end

        # # process prefilter
        #   if field_prefilter.nil?
        #     return rv
        #   else
        #     return field_prefilter.to_elasticsearch_query(fname_pre, field_name_post.to_s.gsub(/^\./,''), rv)
        #   end

          return rv
        end
      end


      rule :field_prefilter, :field_prefilter_start, :field_prefilter_subfield, :field_prefilter_op_eql, :field_prefilter_value, :field_prefilter_end do
        def to_elasticsearch_query(array_base, first_field_name, field_query)
          return field_query if array_base.nil?

          field_prefilter_query = field_prefilter_value.to_s
          field_prefilter_query.gsub!('.', '\\.')
          field_prefilter_query.gsub!('*', '.*')
          field_prefilter_query = {'$regex' => field_prefilter_query, '$options' => 'i'}

        # wrap the incoming field_query with an elemMatch condition that includes the query + the prefilter constraint
          return {
            array_base => {
              '$elemMatch' => {
                first_field_name              => field_query.values.first,
                field_prefilter_subfield.to_s => field_prefilter_query
              }
            }
          }
        end
      end


    # process coercion modifier
      rule :field_modifier, :coercer, :modifier do
        def get_coercer
          return coercer
        end
      end

      rule :values, many(:value, :valueop_or) do
        def to_a
          value
        end
      end

    # process test value and modifiers
      rule :value, :value_modifier_unary?, :value_value? do
        def to_elasticsearch_query(field, coerce=nil)
          if coerce.nil?
            rv = value_value.to_s.autotype()
          else
            rv = value_value.to_s.convert_to(coerce)
          end

          if value_modifier_unary
            vmu = value_modifier_unary.to_elasticsearch_query(rv)

          # handle not operator
            if vmu.first.first == :not
            # handle not:null test
              if vmu.first.last.nil?
                return {
                  :bool => {
                    :must_not => {
                      :missing => {
                        :field     => field,
                        :existence => true,
                        :null_value => true
                      }
                    }
                  }
                }
              else
                return {
                  :not => {
                    :term => {
                      field => vmu.first.last
                    }
                  }
                }
              end
            else
              return {
                :range => {
                  field => vmu
                }
              }
            end

        # testing for a null value is a snowflake
          elsif value_value.to_s == 'null'
            return ({
              :bool => {
                :must => {
                  :missing => {
                    :field     => field,
                    :existence => true,
                    :null_value => true
                  }
                }
              }
            })

          elsif rv.is_a?(String)
            if rv =~ /[\\[\\*\\?\\{}]]/
              rv.gsub!('.', '\\.')
              rv.gsub!('*', '.*')

              return {
                :regexp => {
                  field => rv,
                }
              }
            else
            # internal fields should use term search
              if field[0].chr == '_'
                return {
                  :term => {
                    field => rv
                  }
                }
              else
            # DEFAULT: use a phrase_prefix match query
                return {
                  :query => {
                    :match => {
                      field => {
                        :query => rv,
                        :type  => :phrase_prefix
                      }
                    }
                  }
                }
              end
            end

        # perform a straight term search for everything else
          else
            return {
              :term => {
                field => rv
              }
            }
          end
        end

        def empty?
          value_value.to_s.empty?
        end
      end


    # process value modifier functions
      rule :value_modifier_unary, :value_function_unary, :modifier do
        def to_elasticsearch_query(value)
          case value_function_unary.to_sym
          when :gt, :gte, :lt, :lte
            return Hash[value_function_unary, value]

          when :since
            return Hash[:gte, value]

          when :before
            return Hash[:lte, value]

          when :not
            return Hash[:not, value]

          else return value
          end
        end
      end


      rule :coercer,                  /[a-z\_]+/
      rule :modifier,                 ':'
      rule :field_name_pre,           /[a-zA-Z0-9\_\.]+/
      rule :field_name_post,          /[a-zA-Z0-9\_\.]+/
      rule :fieldop_or,               '|'
      rule :field_prefilter_start,    '['
      rule :field_prefilter_subfield, /[a-zA-Z0-9\_\.]+/
      rule :field_prefilter_op_eql,   '='
      rule :field_prefilter_value,    /\w+/
      rule :field_prefilter_end,      ']'
      rule :pairer,                   '/'
      rule :value_function_unary,     /[a-z]+/
      rule :value_value,              /[^\/]*/
      rule :valueop_or,               '|'
    end
  end
end
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

require 'babel_bridge'
module App
  module Helpers
    class MongoUrlqueryParser < BabelBridge::Parser
      TOP_LEVEL_FIELDS = ['id', 'parent_id', 'name', 'tags', 'aliases', 'status', 'updated_at', 'created_at', 'collected_at']
      DEFAULT_FIELD_PREFIX='properties'

    # process the whole query
      rule :mongo, many(:pair, :pairer) do
        def to_mongo_query()
          return {'$and' =>
            pair.collect{|e|
              e.to_mongo_query
            }.flatten
          }
        end
      end

    # process pairs of field/[value] parameters
      rule :pair, many(:field, :fieldop_or), :pairer?, :values? do
        def to_mongo_query
          return ({
            '$or' => field.collect{|f|
              if values.to_a.empty?
                f.to_mongo_query(nil)
              else
                values.to_a.collect{|v|
                  f.to_mongo_query(v)
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
          when Regexp.new("^(#{App::Helpers::MongoUrlqueryParser::TOP_LEVEL_FIELDS.join('|')})$")
            return field
          else
            return "#{prefix}.#{field}"
          end
        end

        def to_mongo_query(value=nil)
          fname_pre = translate_field(field_name_pre.to_s, DEFAULT_FIELD_PREFIX)
          fname = fname_pre + field_name_post.to_s
          rv = nil

        # no value
          if value.empty?
          # check for unary modifiers
            if field_modifier.nil?
              rv = { fname => {'$exists' => true} }
            else
              case field_modifier.get_coercer.to_sym
              when :absent
                rv = { fname => {'$exists' => false} }
              end
            end
          else
            rv = { fname => value.to_mongo_query(field_modifier.nil? ? (fname =~ /_(?:at|or)$/i ? :date : nil) : field_modifier.get_coercer) }
          end

        # process prefilter
          if field_prefilter.nil?
            return rv
          else
            return field_prefilter.to_mongo_query(fname_pre, field_name_post.to_s.gsub(/^\./,''), rv)
          end
        end
      end


      rule :field_prefilter, :field_prefilter_start, :field_prefilter_subfield, :field_prefilter_op_eql, :field_prefilter_value, :field_prefilter_end do
        def to_mongo_query(array_base, first_field_name, field_query)
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
        def to_mongo_query(coerce=nil)
          return nil if value_value.nil?

          if coerce.nil?
            rv = value_value.to_s.autotype()
          else
            rv = value_value.to_s.convert_to(coerce)
          end

          rv = value_modifier_unary.to_mongo_query(rv) if value_modifier_unary

        # default to regex searches
          if rv.is_a?(String)
            rv.gsub!('.', '\\.')
            rv.gsub!('*', '.*')

            return {'$regex' => rv, '$options' => 'i'}
          end

          return rv
        end

        def empty?
          value_value.to_s.empty?
        end
      end


    # process value modifier functions
      rule :value_modifier_unary, :value_function_unary, :modifier do
        def to_mongo_query(value)
          case value_function_unary.to_sym
          when :gt, :gte, :lt, :lte, :in, :nin
            return Hash["$#{value_function_unary}", value]

          when :since
            return Hash["$gte", value]

          when :before
            return Hash["$lte", value]

          when :not
            return Hash["$ne", value]

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
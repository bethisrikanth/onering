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

    # process field name and modifiers
      rule :field, :field_modifier?, :field_name do
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
          fname = translate_field(field_name.to_s, DEFAULT_FIELD_PREFIX)

        # no value
          if value.empty?
          # check for unary modifiers
            if field_modifier.nil?
              return { fname => {'$exists' => true} }
            else
              case field_modifier.get_coercer.to_sym
              when :absent
                return { fname => {'$exists' => false} }
              end
            end
          else
            return { fname => value.to_mongo_query(field_modifier.nil? ? (fname =~ /_(?:at|or)$/i ? :date : nil) : field_modifier.get_coercer) }
          end
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


      rule :coercer, /[a-z\_]+/
      rule :modifier, ":"
      rule :field_name, /[a-zA-Z0-9\_\.]+/
      rule :fieldop_or, '|'
      rule :pairer, '/'
      rule :value_function_unary, /[a-z]+/
      rule :value_value, /[^\/]*/
      rule :valueop_or, '|'
    end
  end
end
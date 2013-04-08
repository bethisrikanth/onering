require 'babel_bridge'
module App
  module Helpers
    class MongoUrlqueryParser < BabelBridge::Parser
      TOP_LEVEL_FIELDS = ['id', 'parent_id', 'name', 'tags', 'aliases', 'status']
      DEFAULT_FIELD_PREFIX='properties'

    # process the whole query
      rule :mongo, many(:pair, :pairer) do
        def to_mongo_query()
          {'$and' =>
            pair.collect{|e|
              e.to_mongo_query
            }
          }
        end
      end

    # process pairs of field/[value] parameters
      rule :pair, many(:field, :fieldop_or), match?(:pairer), match?(:value) do
        def to_mongo_query
          ({
            '$or' => field.collect{|f|
              f.to_mongo_query(value)
            }
          })
        end
      end

    # process field name and modifiers
      rule :field, match?(:field_modifier), :field_name do
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
              when :null
                return { fname => nil }
              end
            end
          else
            return { fname => value.to_mongo_query(field_modifier.nil? ? nil : field_modifier.get_coercer) }
          end
        end
      end


    # process coercion modifier
      rule :field_modifier, :coercer, :modifier do
        def get_coercer
          coercer
        end
      end

    # process test value and modifiers
      rule :value, match?(:value_modifier_unary), match?(:value_value) do
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
            rv = {'$regex' => Regexp.quote(rv), '$options' => 'i'}
          else
            rv
          end
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

          when :not
            return Hash["$ne", value]

          else return value
          end
        end
      end


      rule :coercer, /[a-z\_]+/
      rule :modifier, ":"
      rule :field_name, /[a-zA-Z0-9\_\.]+/
      rule :fieldop_absent, "absent"
      rule :fieldop_null,   "null"
      rule :fieldop_or, '|'
      rule :pairer, '/'
      rule :value_function_unary, /[a-z]+/
      rule :value_value, /[^\/]*/
    end
  end
end
module Urlquery
  module Operators
    class IsOperator < Urlquery::Operator
      def to_query(field, value)
        if value.nil?
          return ({
            :missing => {
              :field      => field,
              :existence  => true,
              :null_value => true
            }
          })
        else
          if value.is_a?(String)
            return ({
              :regexp => {
                field => {
                  :value => "^#{value}$",
                  :flags => :ALL
                }
              }
            })
          else
            return ({
              :term => {
                field => value
              }
            })
          end
        end
      end
    end
  end
end

module Urlquery
  module Operators
    class NotOperator < Urlquery::Operator
      def to_query(field, value)
        if value.nil?
          return ({
            :bool => {
              :must_not => {
                :missing => {
                  :field      => field,
                  :existence  => true,
                  :null_value => true
                }
              }
            }
          })
        else
          if value.is_a?(String)
            return ({
              :bool => {
                :must_not => {
                  :regexp => {
                    field => {
                      :value => "^#{value}$",
                      :flags => :ALL
                    }
                  }
                }
              }
            })
          else
            return ({
              :bool => {
                :must_not => {
                  :term => {
                    field => value
                  }
                }
              }
            })
          end
        end
      end
    end
  end
end

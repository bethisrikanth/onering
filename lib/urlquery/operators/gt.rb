module Urlquery
  module Operators
    class GtOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :range => {
            field => {
              :gt => value
            }
          }
        })
      end
    end
  end
end

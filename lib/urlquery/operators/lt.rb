module Urlquery
  module Operators
    class LtOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :range => {
            field => {
              :lt => value
            }
          }
        })
      end
    end
  end
end

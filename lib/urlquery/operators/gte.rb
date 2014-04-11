module Urlquery
  module Operators
    class GteOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :range => {
            field => {
              :gte => value
            }
          }
        })
      end
    end
  end
end

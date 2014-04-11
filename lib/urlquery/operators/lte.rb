module Urlquery
  module Operators
    class LteOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :range => {
            field => {
              :lte => value
            }
          }
        })
      end
    end
  end
end

module Urlquery
  module Operators
    class PrefixOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :prefix => {
            field => value
          }
        })
      end
    end
  end
end

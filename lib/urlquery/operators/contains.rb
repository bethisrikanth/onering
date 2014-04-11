module Urlquery
  module Operators
    class ContainsOperator < Urlquery::Operator
      def to_query(field, value)
        return ({
          :regexp => {
            field => {
              :value => value,
              :flags => :ALL
            }
          }
        })
      end
    end
  end
end
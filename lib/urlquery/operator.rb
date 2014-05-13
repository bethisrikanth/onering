module Urlquery
  class Operator
    def to_query(field, value)
      nil
    end

    def self.skip_normalizer()
      false
    end
  end
end
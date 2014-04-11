module Urlquery
  class Error < Exception; end
  class QueryValidationError < Error; end
  class QuerySyntaxError < Error; end
  class InvalidOperatorError < QuerySyntaxError; end
end
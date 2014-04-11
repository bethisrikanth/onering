require          'active_support/inflector'
require_relative 'patches'
require_relative 'urlquery/errors'
require_relative 'urlquery/operator'
require_relative 'urlquery/query'

Dir[File.join(File.dirname(__FILE__), 'urlquery', 'operators', '*.rb')].each{|i|
  require_relative "urlquery/operators/#{File.basename(i, '.rb')}"
}

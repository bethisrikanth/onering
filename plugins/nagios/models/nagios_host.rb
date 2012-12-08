require 'model'

class NagiosHost < App::Model::Base
  set_collection_name "nagios"

  timestamps!

  key :name,            String
  key :host,            Array
  key :service,         Array
end
require 'model'

class AutomationRequest < App::Model::Base
  set_collection_name "automation_requests"

  timestamps!

  key :job_id,    String
  key :commands,  Array
  key :arguments, Array
  key :devices,   Array


end

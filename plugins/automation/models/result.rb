require 'model'

module Automation
  class Result < App::Model::Base
    set_collection_name "automation_results"

    timestamps!

    key :job_id,    String
    key :device_id, String
    key :output,    String
  end
end

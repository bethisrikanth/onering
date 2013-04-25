require 'model'
require 'queue'

module Automation
  class Request < App::Model::Base
    set_collection_name "automation_requests"

    timestamps!

    key :status,      String, :default => :unknown
    key :job_id,      String
    key :parameters,  Hash
    key :source,      String
    key :user,        String
    key :anonymous,   Boolean, :default => false
    key :started_at,  Time, :default => nil
    key :finished_at, Time, :default => nil
    key :results,     Array

    def job()
      return Job.find(self.job_id)
    end
  end
end

require 'model'
require 'queue'

module Automation
  class Request < App::Model::Base
    set_collection_name "automation_requests"

    timestamps!

    key :status,    String, :default => :unknown
    key :job_id,    String
    key :parameters,  Hash
    key :source,    String
    key :user,    String
    key :anonymous,   Boolean, :default => false
    key :started_at,  Time, :default => nil
    key :finished_at, Time, :default => nil
    key :results,   Array

    def job()
      return Job.find(self.job_id)
    end



    def serializable_hash(options = {})
      super(options).merge({
        :runtime => (((self.finished_at || Time.now).to_i) - (self.started_at || self.created_at).to_i)
      })
    end
  end
end

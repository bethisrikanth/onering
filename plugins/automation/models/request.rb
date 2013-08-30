require 'model'
require 'queue'

module Automation
  class Request < App::Model::Elasticsearch
    index_name "automation_requests"

    property :status,      :type => 'string',  :default => :unknown
    property :job_id,      :type => 'string'
    property :parameters,  :default => {}
    property :tasks,       :default => []
    property :source,      :type => 'string'
    property :user,        :type => 'string'
    property :anonymous,   :type => 'boolean', :default => false
    property :started_at,  :type => 'date'
    property :finished_at, :type => 'date'
    property :results,     :default => []
    property :created_at,  :type => 'date',    :default => Time.now
    property :updated_at,  :type => 'date',    :default => Time.now

    def job()
      return Job.find_by_id(self.job_id)
    end

    # def serializable_hash(options = {})
    #   super(options).merge({
    #     :runtime => (((self.finished_at || Time.now).to_i) - (self.started_at || self.created_at).to_i)
    #   })
    # end
  end
end

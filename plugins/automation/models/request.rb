require 'model'
require 'queue'

module Automation
  class Request < App::Model::Elasticsearch
    index_name "automation_requests"

    key :status,      :string,  :default => 'unknown'
    key :job_id,      :string
    key :parameters,  :object
    key :tasks,       :object,  :array => true
    key :source,      :string
    key :user,        :string
    key :anonymous,   :boolean, :default => false
    key :started_at,  :date
    key :finished_at, :date
    key :results,     :string,  :array => true
    key :created_at,  :date,    :default => Time.now
    key :updated_at,  :date,    :default => Time.now

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

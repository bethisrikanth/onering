require 'model'
require 'queue'

module Automation
  class Request < App::Model::Elasticsearch
    index_name "automation_requests"

    field :status,      :string,  :default => 'unknown'
    field :job_id,      :string
    field :parameters,  :object
    field :tasks,       :object,  :array => true
    field :source,      :string
    field :user,        :string
    field :anonymous,   :boolean, :default => false
    field :started_at,  :date
    field :finished_at, :date
    field :results,     :string,  :array => true
    field :created_at,  :date,    :default => Time.now
    field :updated_at,  :date,    :default => Time.now

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

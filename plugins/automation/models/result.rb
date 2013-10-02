require 'model'

module Automation
  class Result < App::Model::Elasticsearch
    index_name "automation_results"

    field :job_id,     :string
    field :device_id,  :string
    field :output,     :string
    field :created_at, :date,  :default => Time.now
    field :updated_at, :date,  :default => Time.now
  end
end

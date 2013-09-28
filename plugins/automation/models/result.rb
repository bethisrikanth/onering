require 'model'

module Automation
  class Result < App::Model::Elasticsearch
    index_name "automation_results"

    key :job_id,     :string
    key :device_id,  :string
    key :output,     :string
    key :created_at, :date,  :default => Time.now
    key :updated_at, :date,  :default => Time.now
  end
end

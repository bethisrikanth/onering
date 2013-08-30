require 'model'

module Automation
  class Result < App::Model::Elasticsearch
    index_name "automation_results"


    property :job_id,     :type => 'string'
    property :device_id,  :type => 'string'
    property :output,     :type => 'string'
    property :created_at, :type => 'date',  :default => Time.now
    property :updated_at, :type => 'date',  :default => Time.now
  end
end

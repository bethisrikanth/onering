require 'model'

class NagiosHost < App::Model::Elasticsearch
  index_name "nagios"


  key :name,        :string
  key :alerts,      :object,  :array => true
  key :created_at,  :date,    :default => Time.now
  key :updated_at,  :date,    :default => Time.now
end
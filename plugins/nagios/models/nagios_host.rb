require 'model'

class NagiosHost < App::Model::Elasticsearch
  index_name "nagios"


  field :name,        :string
  field :alerts,      :object,  :array => true
  field :created_at,  :date,    :default => Time.now
  field :updated_at,  :date,    :default => Time.now
end
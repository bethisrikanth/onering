require 'model'

module Dashboard
  class Graph < App::Model::Elasticsearch
    index_name "dashboard_graphs"


    key :name,       :string
    key :backend,    :string
    key :options,    :object
    key :series,     :string,  :array => true
    key :tags,       :string,  :array => true
    key :created_at, :date,    :default => Time.now
    key :updated_at, :date,    :default => Time.now
  end
end
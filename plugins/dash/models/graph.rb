require 'model'

module Dashboard
  class Graph < App::Model::Elasticsearch
    index_name "dashboard_graphs"


    field :name,       :string
    field :backend,    :string
    field :options,    :object
    field :series,     :string,  :array => true
    field :tags,       :string,  :array => true
    field :created_at, :date,    :default => Time.now
    field :updated_at, :date,    :default => Time.now
  end
end
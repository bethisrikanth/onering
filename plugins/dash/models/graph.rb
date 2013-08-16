require 'model'

module Dashboard
  class Graph < App::Model::Elasticsearch
    index_name "dashboard_graphs"


    property :name,       :type => 'string'
    property :backend,    :type => 'string'
    property :options,    :default => {}
    property :series,     :default => []
    property :tags,       :default => []
    property :created_at, :type => 'date',    :default => Time.now
    property :updated_at, :type => 'date',    :default => Time.now
  end
end
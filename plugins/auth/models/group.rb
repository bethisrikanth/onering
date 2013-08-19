require 'model'

class Group < App::Model::Elasticsearch
  index_name "groups"

  property :name,       :type => 'string'
  property :users,      :default => []
  property :created_at, :type => 'date',    :default => Time.now
  property :updated_at, :type => 'date',    :default => Time.now

  def capabilities
    Capability.urlquery("groups/#{self.id}").collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end
end
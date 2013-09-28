require 'model'

class Group < App::Model::Elasticsearch
  index_name "groups"

  key :name,       :string
  key :users,      :string,  :array => true
  key :created_at, :date,    :default => Time.now
  key :updated_at, :date,    :default => Time.now

  def capabilities
    Capability.urlquery("groups/#{self.id}").collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end
end
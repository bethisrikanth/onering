require 'model'

class Group < App::Model::Elasticsearch
  index_name "groups"

  field :name,       :string
  field :users,      :string,  :array => true
  field :created_at, :date,    :default => Time.now
  field :updated_at, :date,    :default => Time.now

  def capabilities
    Capability.urlquery("groups/#{self.id}").collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end
end
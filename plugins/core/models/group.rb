require 'model'

class Group < App::Model::Base
  set_collection_name "groups"

  timestamps!

  key :name,  String
  key :users, Array

  def capabilities
    Capability.where({
      :groups => id
    }).collect{|c|
      (c.capabilities ? c.capabilities : c.id)
    }.flatten
  end
end
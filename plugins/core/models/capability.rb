require 'model'

class Capability < App::Model::Base
  set_collection_name "capabilities"

  timestamps!
  
  key :users,  Array
  key :groups, Array

  def all_users
    rv = []
    rv += users if users
    rv += groups.collect{|i| Group.find(i).users rescue [] }.flatten if groups
    rv
  end

  class<<self
    def users_that_can(key)
      users = []

    # add users specifically named for this capability
      users += (find(key).all_users rescue [])

    # add users named in a group containing this capability
      users += (where({
        :capabilities => key
      }).collect{|i| i.all_users }.flatten)

      users
    end

    def user_can?(id, key)
      users_that_can(key).include?(id)
    end
  end
end
require 'model'

class Capability < App::Model::Elasticsearch
  index_name "capabilities"

  property :users,        :default => []
  property :groups,       :default => []
  property :description,  :type => 'string'
  property :capabilities
  property :children
  property :created_at,   :type => 'date',    :default => Time.now
  property :updated_at,   :type => 'date',    :default => Time.now


  def all_users
    rv = []
    rv += users if users
    rv += groups.collect{|i| Group.find(i).users rescue [] }.flatten if groups
    rv
  end

  class<<self
    def tree(root=nil)
      rv = []

      where({
        :filter => {
          :exists => {
            :field => :capabilities
          }
        }
      }).each do |capability|
        capability = capability.to_h
        capability.set(:children, capability.get(:capabilities,[]).collect{|c|
          find(c).to_h.compact
        })

        rv << capability.compact
      end

      rv
    end

    def users_that_can(key)
      users = []

    # add users specifically named for this capability
      users += (find(key).all_users rescue [])

    # add users named in a group containing this capability
      users += (urlquery("capabilities/#{key}").collect{|i| i.all_users }.flatten)

      users
    end

    def user_can?(id, key)
      users_that_can(key).include?(id)
    end
  end
end
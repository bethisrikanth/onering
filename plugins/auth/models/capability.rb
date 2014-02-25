# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'model'

class Capability < App::Model::Elasticsearch
  index_name "capabilities"

  field :description,  :string
  field :users,        :string,  :array => true
  field :groups,       :string,  :array => true
  field :capabilities, :string,  :array => true


  def all_users()
    rv = []
    rv += self.users() if self.users()
    rv += self.groups.collect{|i| Group.find(i).users rescue [] }.flatten unless self.groups.empty?
    rv
  end

  class<<self
    def tree(root=nil)
      rv = []

      search({
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
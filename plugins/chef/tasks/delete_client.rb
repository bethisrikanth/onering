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

module Automation
  module Tasks
    module Chef
      require 'ridley'
      
      class DeleteClient < Task
        def self.perform(id, node={}, *args)

          config = App::Config.get!('chef.client')
          fail("Malformed Chef client configuration; expected Hash but got #{config.class.name}") unless config.is_a?(Hash)

          chef = Ridley.new({
            :server_url   => config.get(:server_url),
            :client_name  => config.get(:username),
            :client_key   => config.get(:keyfile)
          })

          client = nil
          candidate_clients = []
          candidate_clients << node.get('chef.name')
          candidate_clients << node.get('name')
          candidate_clients << id

          candidate_clients.compact.each do |candidate|
            if (client = chef.client.find(candidate))
              break
            end
          end

          fail("Could not find a Chef client for node #{id}") if client.nil?

          info("Deleting Chef client #{client.name}")
          chef.client.delete(client)
        end
      end
    end
  end
end

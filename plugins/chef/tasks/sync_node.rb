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
      class SyncNode < Task
        def self.perform(id, *args)
          require 'ridley'

          config = App::Config.get!('chef.client')
          fail("Malformed Chef client configuration; expected Hash but got #{config.class.name}") unless config.is_a?(Hash)

          keyfield = App::Config.get('chef.node.keyfield', 'id')
          debug("Using asset field #{keyfield} to locate associated Chef node")

          chef = Ridley.new({
            :server_url   => config.get(:server_url),
            :client_name  => config.get(:username),
            :client_key   => config.get(:keyfile),
            :ssl => {
              :verify => false
            }
          })

          asset = Asset.find(id)
          fail("Asset #{id} not found") if asset.nil?

          key = asset.get(keyfield)
          fail("Asset field #{keyfield} is missing, skipping...") if key.nil?

          chef_node = chef.node.find(key)
          fail("Chef node #{key} could not be found for asset #{id}") if chef_node.nil?

          info("Updating Chef node #{key}...")

          %w{
            chef_environment
            run_list
            default
            normal
            override
          }.each do |a|
            if not (field = config.get("nodes.template.#{a}")).nil?
              if not (value = asset.get(field)).nil?
                chef_node.send(:"#{a}=", value)
                debug("-> #{a} with #{value.class.name}")
              end
            end
          end
        end
      end
    end
  end
end

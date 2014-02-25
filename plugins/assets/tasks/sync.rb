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

require 'set'
require 'assets/models/asset'
require 'assets/models/node_default'

module Automation
  module Tasks
    module Assets
      class Sync < Task
        def self.perform(*args)
          ids = Set.new()

        # resync defaults
          NodeDefault.urlquery('bool:enabled/true').each do |default|
            nodes = default.devices.to_a
            next unless nodes.length > 0

            info("Resyncing #{nodes.length} nodes with rule: #{default.name}")

          # add IDs to a set to ensure they only get synced once
            ids += nodes
          end

          if ids.empty?
            info("No devices required sync")

          else
            info("Adding #{ids.length} nodes to queue for resync")

            ids.each do |id|
            # queue this node
              run_low('assets/update', {
                :id => id
              }, true)
            end
          end
        end
      end
    end
  end
end
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
    module Chef
      class Sync < Task
        def self.perform(*args)
          config = App::Config.get('chef.nodes',{})
          filter = (args.first || config.get(:filter))

        # if no filter was specified (either in the call or in the config), default to all assets
          if filter.nil?
            assets = Asset.ids()
          else
            assets = Asset.list(:id, filter)
          end

          assets.each do |id|
            run_low('chef/sync_node', id)
          end
        end
      end
    end
  end
end
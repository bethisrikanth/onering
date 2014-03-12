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
require 'assets/models/registered_address'

module Automation
  module Tasks
    module Assets
      module Ipam
        class SyncPool < Task
          def self.perform(pool, *args)
            config = App::Config.get("assets.ipam.pools.#{pool}")
            return nil if config.nil?

            range_ips = RegisteredAddress.get_pool_addresses(pool)

            if range_ips.empty?
              warn("Pool #{pool} returned no addresses, skipping...")
              return nil
            end
            debug("Populating pool #{pool} with #{range_ips.length} addresses")

            range_ips.each do |ip|
              run_low('assets/ipam/check_claim', ip, pool)
            end
          end
        end
      end
    end
  end
end
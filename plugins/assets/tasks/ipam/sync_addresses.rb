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
require 'assets/models/registered_address'

module Automation
  module Tasks
    module Assets
      module Ipam
        class SyncAddresses < Task
          def self.perform(*args)
            config = App::Config.get("assets.ipam.autoassign")
            return nil if config.nil?
            fail("Configuration must specify a target field for address assignment") unless config.get('target.field')

            debug("Auto-assigning addresses to assets matching: #{config.get(:query)}")

            assets = Asset.urlquery(config.get(:query))

            return nil if assets.empty?
            info("Auto-assigning addresses to #{assets.length} assets")

            assets.each do |asset|
              if asset.get('ipam.pool')
                current = asset.get(config.get('target.field'))

                if current.nil?
                  begin
                  # attempt to find an existing address
                    address = RegisteredAddress.urlquery("bool:reserved/false/str:asset_id/#{asset.id}").first

                  # get a new IP if none already exists
                    address = RegisteredAddress.next_unclaimed_address(asset.get('ipam.pool'), asset.id, {
                      :selection => config.get(:strategy),
                      :retries   => config.get(:retries)
                    }) if address.nil?
                  rescue AddressPoolFullError => e
                    warn(e.message)
                    fail("Could not auto-assign address for asset #{asset.id} in pool #{asset.get('ipam.pool')}: Pool has no available addresses remaining")
                  end

                  info("Assigning IP #{address.value} to asset #{asset.id}, setting field #{config.get('target.field')}")
                  asset.set(config.get('target.field'), address.value)
                  asset.save()
                else
                  warn("Asset #{asset.id} already has the value '#{current}' set to field #{config.get('target.field')}, will not replace")
                end
              else
                warn("Asset #{asset.id} does not belong to an IPAM pool, cannot auto-assign address")
              end
            end
          end
        end
      end
    end
  end
end
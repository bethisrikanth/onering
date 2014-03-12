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
        class CheckClaim < Task
          def self.perform(ip, pool, *args)
            config = App::Config.get("assets.ipam.pools.#{pool}")
            return nil if config.nil?

            info("Validating IP address #{ip}")

            claim_fields = App::Config.get('assets.ipam.claim_fields', ['ip'])
            debug("Fields that contain IP addresses that an asset exclusively owns: #{claim_fields.join(',')}")

          # attempt to find an asset that owns this IP address
            asset = Asset.urlquery("#{claim_fields.join('|')}/is:#{ip}").first

            address = RegisteredAddress.urlquery("str:value/is:#{ip}").first
            address = RegisteredAddress.new({
              :value => ip
            }) if address.nil?

          # set the address pool
            address.pool = pool

          # IP does not belong to an asset, perform low level tests to see if it is available
            if asset.nil?
              if RegisteredAddress.ip_available?(ip) and not address.claimed?
              # IP is not claimed and not contactable
                info("Releasing unclaimed IP #{ip}")
                address.release()
              else
              # IP is contactable or already claimed
                info("Claiming IP #{ip} anonymously")
                address.claim()
              end
            else
            # claim this IP for a specific asset
              info("Claiming IP #{ip} for asset #{asset.id}")
              address.claim(asset.id)
            end

            debug("Saving IP #{ip}, #{address.claimed? ? 'claimed' : 'unclaimed'} #{address.asset_id ? 'for asset '+address.asset_id : ''}")
            address.save({
              :replication => :sync
            })
          end
        end
      end
    end
  end
end
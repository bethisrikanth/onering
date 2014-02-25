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
      class SyncPools < Task
        def self.perform(pools=nil, assets=nil, *args)
          ip_pool = {}
          address_cache = {}
          pools  = pools.split(',') if pools.is_a?(String)
          assets = assets.split(',') if assets.is_a?(String)

        # map all possible IPs in all ranges to their pool names
          App::Config.get('assets.ipam.pools', {}).each do |name, ranges|
            next if not pools.nil? and not pools.include?(name)

            range_ips = RegisteredAddress.get_pool_addresses(name)

          # map final set of IPs to pool names
            range_ips.uniq.each do |ip|
              ip_pool[ip] = name
            end

            debug("Populating pool #{name} with #{range_ips.length} addresses")
          end

          check_fields = App::Config.get('assets.ipam.check_fields', [])
          debug("Fields to check for IP address data: #{check_fields.join(',')}")

          claim_fields = App::Config.get('assets.ipam.claim_fields', ['ip'])
          debug("Fields that contain IP addresses that an asset exclusively owns: #{claim_fields.join(',')}")

          fields = (check_fields + claim_fields).sort.uniq

          if assets.nil?
            assets = Asset.all(:fields => fields)
          else
            assets = Asset.find(assets)
          end

          info("Syncing #{assets.length} assets")

        # for each asset, if there is a corresponding pool for the IPs found in that
        # asset's "claim_fields", claim that IP in the name of that asset
        #
        # otherwise claim it anonymously
        #
          assets.each do |asset|
            pool = nil

            fields.each do |f|
              ips = [*asset.get(f,[])]
              ips.flatten.collect{|i|
                i.split(/\s+/)
              }.flatten.each do |ip|
              # validate that we're looking at an IP address
                if not ip =~ /^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$/
                  warn("#{asset.id}/#{f}: value '#{ip}' is not an IP address, skipping...")
                  next
                end

              # if we've already queried this IP during this run, use the cached copy
              # instead of re-running the query
              #
                if address_cache.has_key?(ip) and address_cache[ip].is_a?(RegisteredAddress)
                  address = address_cache[ip]
                else
                  address = RegisteredAddress.urlquery("str:value/#{ip}").first
                  address = RegisteredAddress.new({
                    :value => ip
                  }) if address.nil?
                end


              # if this IP is associated with a named pool, set the pool value to that name
                if not ip_pool[ip].nil?
                  address.pool = ip_pool[ip]
                end

                if not address.claimed?
                # if this field is one of the fields used to specify an IP that an
                # asset "owns", claim the address for this asset
                  if claim_fields.include?(f)
                    address.claim(asset.id)
                    debug("Address #{ip} belongs to #{address.asset_id}#{address.pool ? ', in pool '+address.pool : ''}")
                  else
                # otherwise just mark the address as claimed without specifying the asset
                    address.claim(nil)
                    debug("Address #{ip} is claimed #{address.pool ? ' in pool '+address.pool : ''}")
                  end
                end

                address_cache[ip] = address unless address_cache.has_key?(ip)
                address.save() if address.dirty?
              end
            end
          end
        end
      end
    end
  end
end
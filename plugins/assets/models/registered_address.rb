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

require 'ipaddress'
require 'resolv'
require 'model'
require 'assets/models/asset'
require 'net/ping'

class RegisteredAddress < App::Model::Elasticsearch
  DEFAULT_MAX_ADDRESS_RETRIES = 5

  index_name "registered_addresses"

  field :pool,        :string,    :index => :not_analyzed
  field :field,       :string,    :index => :not_analyzed
  field :value,       :string,    :index => :not_analyzed
  field :asset_id,    :string,    :index => :not_analyzed
  field :claimed,     :boolean,   :default => false
  field :created_at,  :date,      :default => Time.now
  field :updated_at,  :date,      :default => Time.now
  field :claimed_at,  :date
  field :released_at, :date

  def claim(asset=nil)
    self.claimed = true
    self.claimed_at = Time.now
    self.asset_id = asset unless asset.nil?
    self
  end

  def release()
    self.claimed = false
    self.claimed_at = nil
    self.released_at = Time.now
    self.asset_id = nil
    self
  end

  def claimed?
    self.claimed
  end

  def get_pool_addresses()
    RegisteredAddress.get_pool_addresses(self.pool)
  end

  class<<self
    def get_pool_addresses(pool, exclude=true)
    # map all possible IPs in all ranges to their pool names
      ranges = App::Config.get("assets.ipam.pools.#{pool}", [])
      range_ips = []

    # for each range rule in this pool...
      ranges.each do |range|
      # EXCLUDE
        if exclude and range[0].chr == '-'
        # explicitly remove certain addresses/ranges
          range_ips = (range_ips - IPAddress::IPv4.new(range[1..-1]).to_a.map(&:to_s))

      # INCLUDE
        else
        # add all possible IPs in the given subnet, less the network and broadcast IPs
          net = IPAddress::IPv4.new(range.delete('-'))
          range_ips += (net.to_a.map(&:to_s) - [net.network.to_s] - [net.broadcast.to_s])
        end

      end

      return range_ips.uniq
    end

    def next_unclaimed_address(pool, asset=nil, options={})
      tries = 0
      address = nil

      catch(:retry) do
        raise "Could not find a free address after #{tries} attempts" if tries >= options.get(:retries, DEFAULT_MAX_ADDRESS_RETRIES)

        all_pool_addresses = get_pool_addresses(pool)
        return nil if all_pool_addresses.empty?

        claimed_addresses = RegisteredAddress.urlquery("pool/#{pool}/bool:claimed/true")
        unclaimed_addresses = (all_pool_addresses - claimed_addresses.collect{|i| i.value })

        return nil if unclaimed_addresses.empty?

        ip = nil

        case options[:selection]
        when :first
          ip = unclaimed_addresses.first
        when :last
          ip = unclaimed_addresses.last
        when :middle
          ip = unclaimed_addresses[unclaimed_addresses.length / 2]
        else
          ip = unclaimed_addresses.sample()
        end

      # find/create address
        address = RegisteredAddress.urlquery("str:value/#{ip}").first
        address = RegisteredAddress.new({
          :value => ip
        }) if address.nil?

      # claim it
        address.claim()
        address.save({
          :replication => :sync
        })

      # verify it cannot be pinged
        if not Net::Ping::ICMP.new(ip, nil, 3).ping?
        # verify we can't resolve this IP in DNS
          begin
            Resolv.getname(ip)
            throw :retry

          rescue Resolv::ResolvError
          # proceed to claim this IP for the given asset
            if not asset.nil?
              address.claim(asset)
              address.save({
                :replication => :sync
              })
            end

          # the only successful path to a valid address
            return address
          end
        else
          throw :retry
        end
      end

      return nil
    end
  end
end

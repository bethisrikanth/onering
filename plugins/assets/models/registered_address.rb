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

class AddressPoolFullError < Exception; end

class RegisteredAddress < App::Model::Elasticsearch

  DEFAULT_MAX_ADDRESS_RETRIES = 5

  index_name "registered_addresses"

  field :pool,        :string,    :index => :not_analyzed
  field :field,       :string,    :index => :not_analyzed
  field :value,       :string,    :index => :not_analyzed
  field :asset_id,    :string,    :index => :not_analyzed
  field :claimed,     :boolean,   :default => false
  field :reserved,    :boolean,   :default => false
  field :created_at,  :date,      :default => Time.now
  field :updated_at,  :date,      :default => Time.now
  field :claimed_at,  :date
  field :released_at, :date
  field :comments,    :string

  def claim(asset=nil)
    self.claimed = true
    self.claimed_at = Time.now
    self.asset_id = asset unless asset.nil?
    self
  end

  def release(release_asset=false)
  # if specified, also attempt to clear any associated fields on the linked asset
    if release_asset == true and not self.asset_id.nil?
      asset = Asset.find(self.asset_id)

    # if the asset was found...
      if not asset.nil?
      # check all field that assets may use to hold their own IPs
        App::Config.get('assets.ipam.claim_fields', []).each do |field|
        # if the field's value matches this address, unset it
          if not self.value.nil? and asset.get(field) == self.value
            asset.unset(field)
          end
        end

      # save if necessary
        asset.save() if asset.dirty?
      end
    end

    self.claimed = false
    self.claimed_at = nil
    self.released_at = Time.now
    self.asset_id = nil
    self
  end

  def claimed?
    self.claimed
  end

  def reserved?
    self.reserved
  end

  def available?
    not (self.claimed or self.reserved)
  end

  def get_pool_addresses()
    RegisteredAddress.get_pool_addresses(self.pool)
  end

  class<<self
    def get_pool_addresses(pool, exclude=true)
    # map all possible IPs in all ranges to their pool names
      pool = App::Config.get("assets.ipam.pools.#{pool}", {})
      range_ips = []

    # add IPs to ranges
      pool.get('ranges',[]).each do |range|
        net = IPAddress::IPv4.new(range)
        range_ips += (net.to_a.map(&:to_s) - [net.network.to_s] - [net.broadcast.to_s])
      end

    # if specified, exclude given ranges from output
      if exclude
        pool.get('exclude',[]).compact.each do |ex|
          range_ips = (range_ips - IPAddress::IPv4.new(ex).to_a.map(&:to_s))
        end
      end

      return range_ips.uniq
    end

    def ip_available?(ip)
      claim_fields = App::Config.get('assets.ipam.claim_fields', [])

    # verify no other assets own this field (if field ownership is configured)
      if claim_fields.empty? or (assets = Asset.urlquery("#{claim_fields.join('|')}/is:#{ip}").empty?)

      # verify it cannot be pinged
        if not Net::Ping::ICMP.new(ip, nil, 3).ping?

        # verify we can't resolve this IP in DNS
          begin
            name = Resolv.getname(ip)
            Onering::Logger.debug("Candidate IP address #{ip} PTR record exists, points to #{name}")

          rescue Resolv::ResolvError
            return true
          end
        else
          Onering::Logger.debug("Candidate IP address #{ip} is pingable, skipping")
        end
      else
        Onering::Logger.debug("Candidate IP address #{ip} is already owned by asset(s) #{assets.collect{|i| i.id }.join(', ')}") if defined?(assets)
      end

      return false
    end

    def next_unclaimed_address(pool, asset=nil, options={})
      tries = 0
      address = nil

      catch(:retry) do
        raise AddressPoolFullError.new("Could not find a free address after #{tries} attempts") if tries >= options.get(:retries, DEFAULT_MAX_ADDRESS_RETRIES)

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

        if ip_available?(ip)
          if not asset.nil?
            address.claim(asset)
            address.save({
              :replication => :sync
            })
          end

        # the only successful path to a valid address
          return address
        end
      end

      return nil
    end
  end
end

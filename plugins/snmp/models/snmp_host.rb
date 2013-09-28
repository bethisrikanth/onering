require 'net/ping'
require 'snmp'
require 'ipaddress'
require 'model'
require 'snmp/lib/util'
require 'thread'

class SnmpHost < App::Model::Elasticsearch
  index_name "snmp_hosts"

  key :profile,    :string
  key :properties, :object
  key :failcount,  :integer, :default => 0
  key :created_at, :date,    :default => Time.now
  key :updated_at, :date,    :default => Time.now


  field_prefix :properties

  class<<self
    include App::Helpers::Snmp::Util

    DEFAULT_PING_TIMEOUT = 0.5
    DEFAULT_SNMP_TIMEOUT = 3.5

    def discover(ip_range, options={}, &block)
      mutex = Mutex.new()
      cv = ConditionVariable.new()

      yielder = proc do |response|
        yield response if block_given?
      end

      addresses = IPAddress.parse(ip_range).to_a

      addresses.each do |address|
        address = address.to_s

        pinger = proc do
        # attempt to ping
          if _ping_host(address, options)
            begin
            # attempt to get SNMP sysName, sysDescr
              SNMP::Manager.open({
                :host      => address,
                :port      => options.get('snmp.port', 161).to_i,
                :timeout   => options.get('snmp.timeout', DEFAULT_SNMP_TIMEOUT).to_f,
                :community => options.get('snmp.community', 'public')
              }) do |snmp|
                properties = {}

                (options.get('snmp.oids', [])+[
                  '1.3.6.1.2.1.1.1.0',
                  '1.3.6.1.2.1.1.5.0'
                ]).uniq.each do |oid|
                  properties[oid] = snmp.get_value(oid).to_s
                end

                yielder.call({
                  :id         => address,
                  :properties => properties
                }) unless properties.empty?
              end
            rescue ::SNMP::RequestTimeout
              nil
            end
          end

          if address == addresses.last.to_s
            mutex.synchronize do
              cv.signal()
            end
          end
        end

        EM.defer(pinger)
      end

      return [mutex, cv]
    end

  private
    def _ping_host(address, options={})
      case options.get('ping.type')
      when 'tcp'
        return Net::Ping::TCP.new(address, options.get('ping.port'), options.get('ping.timeout', DEFAULT_PING_TIMEOUT).to_f).ping?
      when 'udp'
        return Net::Ping::UDP.new(address, options.get('ping.port'), options.get('ping.timeout', DEFAULT_PING_TIMEOUT).to_f).ping?
      else
        return Net::Ping::ICMP.new(address, options.get('ping.port'), options.get('ping.timeout', DEFAULT_PING_TIMEOUT)).ping?
      end
    end
  end
end

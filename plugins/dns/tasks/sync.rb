require 'assets/models/device'

module Automation
  module Tasks
    module Dns
      class Sync < Base
        def run(request)
          axfr = {}

          App::Config.get('dns.sync_zones',[]).each do |zone|
            log("Beginning sync for DNS zone #{zone}")

            IO.popen("host -t AXFR -W 10 #{zone}").lines.each do |line|
              next unless line =~ /\s+IN\s+(?:CNAME|A|TXT|SRV|PTR)\s+/
              line = line.strip.chomp.gsub(/\s+/, ' ')

              name, ttl, x, type, target = line.split(' ', 5)

              name = name.gsub(/\.$/,'')
              type = type.downcase.to_sym
              ttl = ttl.to_i
              target = target.gsub(/(?:\"|\.$)/,'')

              axfr[type] ||= {}

              axfr[type][name] = {
                :name   => name,
                :type   => type,
                :ttl    => ttl,
                :target => target,
                :zone   => zone
              }
            end

            log("Retrieved #{axfr.inject(0){|s,i| s+=i[1].length }} records from #{zone}")
          end


          log("Syncing records to nodes")

          records = {}

          axfr[:a].each do |name, record|
            records[record[:target]] ||= {
              :target  => record[:target],
              :records => []
            }

            records[record[:target]][:records] << record
          end

          [:cname, :txt, :srv].each do |type|
            (axfr[type] || []).each do |name, record|
              a_record = get_a_record(name, type, axfr)

              if not a_record.nil?
                records[a_record[:target]][:records] << record
              end
            end
          end

          records.each do |ip, node|
            devices = Device.urlsearch("ip|network.interfaces.addresses.ip/^#{ip}$").to_a

            devices.each do |device|
              device.properties.set(:dns, node[:records])
              device.safe_save
            end
          end

          return nil
        end

      private
        def get_a_record(name, type, records)
          if not records[type][name].nil?
            return get_a_record(records[type][name][:target], type, records)
          end

          return records[:a][name]
        end
      end
    end
  end
end

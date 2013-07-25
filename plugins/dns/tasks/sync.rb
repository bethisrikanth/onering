require 'assets/models/device'

module Automation
  module Tasks
    module Dns
      class Sync < Base
        def run(request)
          axfr = {}

          App::Config.get('dns.sync', {}).each do |rule, config|
            log("Beginning DNS zone sync for rule #{rule}")

            config['zones'].each do |zone|
              catch(:nextzone) do
                config['nameservers'].each do |ns|
                  IO.popen("host -t AXFR -W 5 #{zone} #{ns}") do |io|
                    dump = io.read
                    io.close

                    if $?.to_i == 0
                      log("Zone transfer of #{zone} from nameserver #{ns} was successful, scanning records")

                      dump.lines.each do |line|
                        next unless line =~ /\s+IN\s+(?:CNAME|A|TXT|SRV|PTR)\s+/
                        line = line.strip.chomp.gsub(/\s+/, ' ')

                        name, ttl, x, type, target = line.split(' ', 5)

                        name = name.gsub(/\.$/,'')
                        type = type.downcase.to_sym
                        ttl = ttl.to_i
                        target = target.gsub(/(?:\"|\.$)/,'')

                        axfr[type] ||= {}

                        axfr[type][name] = {
                          :name        => name,
                          :type        => type,
                          :ttl         => ttl,
                          :target      => target,
                          :zone        => zone,
                          :nameserver  => ns,
                          :rule        => rule,
                          :description => config['label']
                        }.compact
                      end

                      throw :nextzone
                    else
                      log("Unable to transfer zone #{zone} from nameserver #{ns}, moving on...", :warn)
                      next
                    end
                  end
                end
              end
            end

          end

          log("Retrieved #{axfr.inject(0){|s,i| s+=i[1].length }} records")

          if opt(:noop)
            log("No-op flag set, skipping node sync")
            return nil
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
            next if ip =~ /^127\.0\./
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

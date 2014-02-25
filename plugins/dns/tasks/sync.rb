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

require 'assets/models/asset'

module Automation
  module Tasks
    module Dns
      class Sync < Task
        def self.perform(noop=false)
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
                      recs = 0

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

                        recs += 1
                      end

                      log("Zone transfer of #{zone} from nameserver #{ns} was successful, got #{recs} records")

                      throw :nextzone
                    else
                      warn("Unable to transfer zone #{zone} from nameserver #{ns}, moving on...")
                      next
                    end
                  end
                end
              end
            end
          end

          if axfr.empty?
            warn("No DNS sync rules configured, nothing to do")
          else
            log("Retrieved #{axfr.inject(0){|s,i| s+=i[1].length }} records")

            if noop
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

            records.each do |ip, rec|
              next if ip =~ /^127\.0\./
              nodes = Asset.urlquery("ip|network.ip/^#{ip}$").to_a

              nodes.each do |node|
                node.properties.set(:dns, rec[:records])
                node.save()
              end
            end
          end
        end

      private
        def self.get_a_record(name, type, records)
          if not records[type][name].nil?
            return get_a_record(records[type][name][:target], type, records)
          end

          return records[:a][name]
        end
      end
    end
  end
end

require 'assets/models/asset'
require 'snmp/lib/util'
require 'snmp/models/snmp_host'

module Automation
  module Tasks
    module Snmp
      class Sync < Task
        extend App::Helpers::Snmp::Util

        DEFAULT_PING_TIMEOUT = 3.0
        DEFAULT_SNMP_TIMEOUT = 3.5

        require 'net/ping'
        require 'snmp'
        require 'digest'
        require 'socket'

        def self.perform(*args)
          EM.run do
            @config = App::Config.get!('snmp')

            @config.get('profiles',[]).each do |name, profile|
              profile = apply_profile_defaults(@config, profile)

              unless profile.get('enabled', true)
                log("Skipping profile #{name} as it was explicitly disabled")
                next
              end

              log("Performing SNMP sync for profile #{name}")

              addresses = SnmpHost.urlquery("profile/#{name}").collect{|i| i.id }
              processed_addresses = 0

          # perform discovery
              addresses.uniq.each do |address|
                query = proc do
                  begin
                    port = (profile.get('protocol.port', 161)).to_i

                    if Net::Ping::ICMP.new(address, port, profile.get('protocol.ping_timeout', DEFAULT_PING_TIMEOUT).to_i).ping?
                      snmp = SNMP::Manager.new({
                        :host      => address,
                        :port      => port,
                        :timeout   => profile.get('protocol.timeout', DEFAULT_SNMP_TIMEOUT),
                        :community => profile.get('protocol.community', 'public')
                      })

                      asset = {}

                      profile.get('register',{}).each_recurse(:intermediate => true) do |k,v,p|
                        if v.is_a?(Hash)
                          if v['_hardwareid']
                            raise "hardwareid directive must be an array" unless v['_hardwareid'].is_a?(Array)

                          # generate hardware signature from unique components
                            signature = v['_hardwareid'].collect{|i|
                              snmp_get(snmp, i)
                            }.reject{|i|
                              i.nil? || i.strip.chomp.empty?
                            }.compact.join('-')

                            raise "Could not determine hardware signature for device #{address}" if signature.to_s.nil_empty.nil?

                          # set signature, calculate and set id
                            asset.set('properties.signature', signature)
                            asset.set('id', Digest::SHA256.new.update(signature).hexdigest[0..5])

                          elsif v['_repeat']
                            raise "repeat directive must be a hash" unless v['_repeat'].is_a?(Hash)

                            unless v['_repeat']['_range'].nil?
                              range = v['_repeat'].delete('_range').collect{|i|
                                snmp_get(snmp, i).to_i
                              }.sort

                              values = []

                            # for each value in
                              range.last.times.to_a.collect{|i|
                                i + range.first
                              }.each do |i|
                                template = {}

                              # retrieve values for each template field
                                v['_repeat'].each_recurse do |kk,vv,pp|
                                  template.set(pp, snmp_get(snmp, vv, i).to_s.autotype())
                                end

                                values << template
                              end

                            # set the appropriate field to what we just built
                              asset.set(p, values)
                            end
                          end

                      # do not process paths whose components have a directive in them
                      # THIS WILL QUITE LIKELY BITE ME IN THE ASS SOMEDAY
                        elsif p.select{|i| i.to_s[0].chr == '_' }.empty?
                          asset.set(p, snmp_get(snmp, v).to_s)
                        end
                      end


                      unless asset.empty?
                      # set details about this collection mechanism
                        asset.set('properties.snmp', {
                          :address   => address,
                          :protocol  => {
                            :version => profile.get('protocol.version')
                          },
                          :collector => {
                            :host         => (Socket.gethostname rescue nil),
                            :profile      => name,
                            :tags         => profile.get('tags')
                          }
                        }.compact)

                        log("Saving asset #{asset.get(:id)} (#{asset.get(:name)})")
                        Asset.new(asset).save()
                      end

                    end
                  rescue ::SNMP::RequestTimeout
                    next
                  rescue Exception => e
                    log("Error handling SNMP device #{address}: #{e.class.name} - #{e.message}", :error)
                    pp e.backtrace
                    next
                  ensure
                    processed_addresses += 1
                  end
                end

                EM.defer(query)

                while processed_addresses < addresses.length
                  sleep 0.1
                end
              end
            end
          end


          # hosts = {}

          # guests = Asset.urlsearch('xen.uuid').to_a

          # if not guests.empty?
          #   log("Linking #{guests.length} Xen guests to their parent hosts")

          #   guests.each do |guest|
          #     uuid = guest.properties.get('xen.uuid')
          #     parent = (hosts[uuid] || Asset.urlsearch("xen.guests/#{uuid}").to_a.first)

          #     if parent
          #     # cache the parent for the duration of this call
          #       hosts[uuid] ||= parent

          #       guest.parent_id = parent.id
          #       guest.save
          #     end
          #   end
          # end



          return nil
        end
      end
    end
  end
end

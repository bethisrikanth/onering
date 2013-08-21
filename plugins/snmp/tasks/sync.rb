require 'assets/models/asset'

module Automation
  module Tasks
    module Snmp
      class Sync < Base
        DEFAULT_PING_TIMEOUT = 0.5
        DEFAULT_SNMP_TIMEOUT = 3.5

        require 'net/ping'
        require 'snmp'
        require 'digest'

        def run(request)
          @config = App::Config.get!('snmp')

          @config.get('profiles',[]).each do |name, profile|
            log("Performing SNMP discovery for profile #{name}")
            profile = @config.get('options.defaults',{}).deeper_merge!(profile)

            addresses = []

          # get addresses from a file, one address per line
            address_list = File.join(@config.get('options.address_lists', File.join(ENV['PROJECT_ROOT'], 'config', 'snmp', 'addresses')), "#{name}.list")

            if File.exists?(address_list)
              list = File.read(address_list).lines.reject{|i|
                i = i.strip.chomp
                true if i.empty?
                true if i[0].chr == '#'
                false
              }.collect{|i|
                i.strip.chomp
              }

              log("Found #{list.length} addresses in file #{address_list}")
              addresses += list
            end

            processed_addresses = 0

          # perform discovery
            addresses.uniq.each do |address|
              query = proc do
                begin
                  port = (profile.get('protocol.port', 161)).to_i

                  if Net::Ping::ICMP.new(address, port, profile.get('protocol.ping_timeout', DEFAULT_PING_TIMEOUT).to_i).ping?
                    snmp = SNMP::Manager.new({
                      :host    => address,
                      :port    => port,
                      :timeout => profile.get('protocol.timeout', DEFAULT_SNMP_TIMEOUT)
                    })

                    filter = profile.get('filter', {})

                    unless filter.empty?
                      filter.each do |oid, pattern|
                        value = snmp.get_value(oid)

                        unless value =~ Regexp.new(pattern)
                          log("Excluding #{address} because filter #{oid} does not match #{pattern}")
                          next
                        end
                      end
                    end

                    asset = {}

                    profile.get('register',{}).each_recurse(:intermediate => true) do |k,v,p|
                      if v.is_a?(Hash)
                        if v['_hardwareid']
                          raise "hardwareid directive must be an array" unless v['_hardwareid'].is_a?(Array)

                        # generate hardware signature from unique components
                          signature = v['_hardwareid'].collect{|i|
                            _snmp_get(snmp, i)
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
                              _snmp_get(snmp, i).to_i
                            }.sort

                            values = []

                          # for each value in
                            range.last.times.to_a.collect{|i|
                              i + range.first
                            }.each do |i|
                              template = {}

                            # retrieve values for each template field
                              v['_repeat'].each_recurse do |kk,vv,pp|
                                template.set(pp, _snmp_get(snmp, vv, i).to_s.autotype())
                              end

                              values << template
                            end

                          # set the appropriate field to what we just built
                            asset.set(p[0..-2], values)
                          end
                        end

                    # do not process paths whose components have a directive in them
                    # THIS WILL QUITE LIKELY BITE ME IN THE ASS SOMEDAY
                      elsif p.select{|i| i.to_s[0].chr == '_' }.empty?
                        asset.set(p, _snmp_get(snmp, v).to_s.autotype())
                      end
                    end

                    log("Saving asset #{asset.get(:id)} (#{asset.get(:name)})")
                    Asset.new(asset).save()


                  end
                rescue ::SNMP::RequestTimeout
                  next
                rescue Exception => e
                  log("Error handling SNMP device #{address}: #{e.class.name} - #{e.message}", :error)
                  e.backtrace.each do |b|
                    log("  #{b}", :debug)
                  end
                  next
                ensure
                  processed_addresses += 1
                end
              end

              EM.defer(query)
            end

            while processed_addresses < addresses.length
              sleep 0.1
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

      private
        def _snmp_get(snmp, field, i=nil)
          match = Regexp.new('(?<pre>.*)\@\{(?:(?<alias>\w+)::)?(?<expr>.+)\}(?<post>.*)').match(field)
          return field if match.nil?

          pre = (match[:pre] =~ /^\@/ ? _snmp_get(snmp, match[:pre], i) : match[:pre])
          expr = match[:expr].strip.split(/\s*\|\s*/)
          post = (match[:post] =~ /^\@/ ? _snmp_get(snmp, match[:post], i) : match[:post])
          oid = expr.shift()

        # check and handle iteration operator
          raise "OID definition '#{oid}' is invalid outside of an iterator" if i.nil? and oid.include?('#')
          oid.gsub!('#', i.to_s) unless i.nil?

          if not match[:alias].empty?
            oid_prefix = @config.get("options.mib.aliases.#{match[:alias]}")
            raise "Unknown MIB alias #{match[:alias]}" if oid_prefix.nil?

            oid = oid_prefix+'.'+oid
          end

          begin
            if snmp.is_a?(::SNMP::Manager)
              value = snmp.get_value(oid)
            elsif snmp.is_a?(Hash)
              value = snmp.get(oid)
            else
              raise "snmp argument must be of type SNMP::Manager or Hash"
            end
          rescue Exception => e
            log("Error retrieving SNMP OID #{oid}: #{e.class.name} - #{e.message}", :warning)
            return nil
          end

          return nil if value.to_s == 'noSuchObject'

          expr.each do |e|
            e = e.split(':')
            func = e.shift()

            begin
              e.collect!{|i|
                case i
                when /^\/.*\/$/
                  Regexp.new(i[1..-2])
                when /^\".*\"/
                  i.to_s[1..-2]
                when /(true|false)/i
                  (i.downcase == 'true' ? true : false)
                else
                  i.autotype()
                end
              }

              value = value.send(func.to_sym, *e)

            rescue Exception => e
              log("Error applying function #{func} to #{oid}=#{value}: #{e.class.name} - #{e.message}", :warning)
              return nil
            end
          end

          return value if pre.empty? and post.empty?
          return pre+value.to_s+post
        end

      end
    end
  end
end

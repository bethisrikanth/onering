module App
  module Helpers
    module Snmp
      module Util
        def apply_profile_defaults(config, profile)
        # get global defaults
          apply_defaults = config.get('options.defaults.any',{}).deep_clone()

        # get and merge any additional defaults
          config.get('options.defaults',{}).each do |tags, defaults|
            next if tags == 'any'
            tags = [*tags].compact

          # if the current profile has all the tags mentioned in this default's required tags list
            if not tags.empty? and (tags & profile.get('tags',[]) == tags)
              apply_defaults.deeper_merge!(defaults)
            end
          end

        # apply these defaults but dont replace existing, more-specific values
          profile.deeper_merge(apply_defaults)

          return profile
        end

        def parse_snmp_field(snmp, field, i=nil)
          match = Regexp.new('(?<pre>[^@]*)(?<oper>\@{1,2})\{(?:(?<alias>\w+)::)?(?<expr>.+)\}(?<post>.*)').match(field)
          return {
            :oid => field
          } if match.nil?


          expr = match[:expr].to_s.strip.split(/\s*\|\s*/)
          oid = expr.shift()

          unless snmp.nil?
            pre = (match[:pre] =~ /^\@/ ? snmp_get(snmp, match[:pre], i) : match[:pre])
            post = (match[:post] =~ /^\@/ ? snmp_get(snmp, match[:post], i) : match[:post])
          end

        # check and handle iteration operator
          raise "OID definition '#{oid}' is invalid outside of an iterator" if i.nil? and oid.include?('#')
          oid.gsub!('#', i.to_s) unless i.nil?

          if not match[:alias].nil? and not match[:alias].empty?
            oid_prefix = App::Config.get("snmp.options.mib.aliases.#{match[:alias]}")
            raise "Unknown MIB alias #{match[:alias]}" if oid_prefix.nil?

            oid = oid_prefix+'.'+oid
          end

          return {
            :alias      => match[:alias],
            :index      => i,
            :prefix     => pre,
            :operator   => match[:oper],
            :expression => expr,
            :postfix    => post,
            :oid        => oid
          }.compact
        end

        def snmp_get(snmp, field, i=nil)
          field = parse_snmp_field(snmp, field, i)

          case field[:operator]
          when '@'
            value = snmp.get_value(field[:oid])
          when '@@'
            value = []
            snmp.walk(field[:oid]){|i|
              value << i.value
            }
          else
            return (field[:oid] || field)
          end

          return nil if value.to_s == 'noSuchObject'

          unless field[:expression].nil?
            field[:expression].each do |e|
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
                return nil
              end
            end
          end

          return value if field[:prefix].nil? and field[:postfix].nil?
          return field[:prefix].to_s+value.to_s+field[:postfix].to_s
        end
      end
    end
  end
end
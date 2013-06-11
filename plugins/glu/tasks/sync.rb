require 'assets/models/device'

module Automation
  module Tasks
    module Glu
      class Sync < Base
        def run(request)
          rv = []
          config = App::Config.get('glu.config')
          fail("Cannot continue without Glu JSON URL") unless config && config['url']
          uri = URI.parse(config['url'])

        # ------------------------------------------------------------------------
        # parse zookie - this gets the deployed versions as reported from the
        # Glu Agent in Zookeeper, via the "Zookie" REST API (internal Outbrain tool)
        #

          zk = App::Config.get('zookie.config')
          zkuri = URI.parse(zk['url'])
          zk_versions = {}

          log("Retrieving Glu agent presence from Zookeeper via #{zkuri.to_s}")

          Net::HTTP.start(zkuri.host, zkuri.port) do |http|
            request = Net::HTTP::Get.new(zkuri.to_s)
            request.basic_auth zk['username'], zk['password'] if zk['username'] && zk['password']
            response = http.request(request)

            zk_json = MultiJson.load(response.body)
            fail("Invalid Zookie response") unless zk_json['children']

            def get_leaf(base)
              if base.is_a?(Hash) and base.has_key?('children') and base['children'].is_a?(Array)
                return base['children'].collect{|i| get_leaf(i) }.flatten
              end

              if base['data']
                data = (MultiJson.load(base['data']) rescue base['data'])

                host = base['path'].split('/')[6]
                return nil unless host

                device = Device.urlsearch("name:aliases/#{host}").first
                hid = (device[:_id] rescue nil)
                return nil unless hid

                return {
                  :id      => hid,
                  :product => (base['path'].split('/')[4].strip rescue nil),
                  :version => (data['revision'] rescue nil)
                }
              end

              nil
            end

            get_leaf(zk_json).each do |node|
              if node
                id = node.delete(:id)

                if id
                  zk_versions[id] ||= {}
                  zk_versions[id][node[:product]] = node[:version]
                end
              end
            end
          end

          log("Retrieving Glu JSON configuration from #{uri.to_s}")

        # parse glu.json
          Net::HTTP.start(uri.host, uri.port) do |http|
            request = Net::HTTP::Get.new(uri.path)
            request.basic_auth config['username'], config['password'] if config['username'] && config['password']
            response = http.request(request)

            glu_json = MultiJson.load(response.body)
            fail("Invalid glu.json format") unless glu_json['entries']

            glu_agents = {}

            glu_json['entries'].each do |entry|
              fail("Invalid Glu agent name '#{entry['agent']}'") if entry['agent'].to_s.strip.chomp.empty?

            # initialize if necessary
              glu_agents[entry['agent']] = {} unless glu_agents[entry['agent']]
              glu_agents[entry['agent']]['apps'] = [] unless glu_agents[entry['agent']]['apps']
              glu_agents[entry['agent']]['tags'] = [] unless glu_agents[entry['agent']]['tags']

            # add app details
              app = {
                'name'          => (entry['metadata']['product'] rescue nil),
                'version'       => (entry['metadata']['version'].to_s rescue nil),
                'mount_point'   => (entry['mountPoint'] rescue nil),
                'tags'          => (entry['tags'] rescue nil),
                'deploy_script' => (entry['script'] rescue nil)
              }

            # add what appear to be more open-ended, but common properties
              ['cluster', 'environment'].each do |i|
                app[i] = entry['metadata'][i] if entry['metadata'][i]
              end

            # put app into the agent object
              glu_agents[entry['agent']]['apps'] << app

            # denormalize: put all tags in a big master list for this agent
              glu_agents[entry['agent']]['tags'] = [glu_agents[entry['agent']]['tags'] + (entry['tags'] rescue [])].flatten.uniq.sort
            end

            log("Syncing Glu configuration to #{glu_agents.length} nodes") unless glu_agents.empty?

          # save glu data
            glu_agents.each do |name, glu_properties|
              device = Device.find_by_name(name)

              if device
                rv << device.id

              # efficient?  no.
              # this exposes the version as reported to Zookeeper from the Glu Agent
              # in the device object
                if zk_versions[device.id]
                  glu_properties['apps'].each do |i|
                    zk_versions[device.id].each do |k,v|
                      if i['name'] == k
                        i['zk_version'] = v.to_s
                        i.replace i
                      end
                    end
                  end
                end

                device['properties'] = {} unless device['properties']
                device['properties']['glu'] = glu_properties
                device.safe_save
              end
            end

          # remove glu properties from hosts not appearing in the glu.json
            glu_missing = (Device.where({'properties.glu' => {'$exists' => true}}).collect{|i| i.name } - glu_agents.keys)
            log("Removing Glu configuration from #{glu_missing.length} nodes") unless glu_missing.empty?

            glu_missing.each do |node|
              node = Device.find_by_name(node)
              next unless node
              node.properties[:glu] = nil
              node.safe_save rescue next
            end
          end

          return nil
        end
      end
    end
  end
end

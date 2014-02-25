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
    module Glu
      class Sync < Task
        def self.perform(*args)
          config = App::Config.get('glu.config',{})
          fail("Cannot continue without Glu JSON URL") unless config && config['url']
          uri = URI.parse(config['url'])

        # ------------------------------------------------------------------------
        # parse zookie - this gets the deployed versions as reported from the
        # Glu Agent in Zookeeper, via the "Zookie" REST API (internal Outbrain tool)
        #

          zk = App::Config.get('zookie.config',{})

          unless zk.empty?
            zkuri = URI.parse(zk['url'])
            zk_versions = {}

            log("Retrieving Glu agent presence from Zookeeper via #{zkuri.to_s}")

            Net::HTTP.start(zkuri.host, zkuri.port) do |http|
              request = Net::HTTP::Get.new(zkuri.to_s)
              request.basic_auth zk['username'], zk['password'] if zk['username'] && zk['password']
              response = http.request(request)

              zk_json = MultiJson.load(response.body)
              fail("Invalid Zookie response") unless zk_json['children']

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
              node = Asset.urlquery("name/#{name}")

              case node.length
              when 0
                warn("Skipping #{name}, could not find any nodes with this name")
                next
              when 1
                node = node.first

              else
                warn("Skipping #{name}, multiple nodes responded to this name: #{node.collect{|i| i.id }.join(', ')}")
                next
              end

            # efficient?  no.
            # this exposes the version as reported to Zookeeper from the Glu Agent
            # in the device object
              if zk_versions
                if zk_versions[node.id]
                  glu_properties['apps'].each do |i|
                    zk_versions[node.id].each do |k,v|
                      if i['name'] == k
                        i['zk_version'] = v.to_s
                        i.replace i
                      end
                    end
                  end
                end
              end

              node.properties.set(:glu, glu_properties)
              node.save()
            end

          # remove glu properties from hosts not appearing in the glu.json
            glu_missing = (Asset.urlquery("properties.glu/not:null").collect{|i| i.name } - glu_agents.keys)
            log("Removing Glu configuration from #{glu_missing.length} nodes") unless glu_missing.empty?

            glu_missing.each do |node|
              Asset.urlquery("name/#{name}").each do |nodes|
                node.properties.set(:glu, nil)
                node.save({
                  :reload => false
                },{
                  :refresh => false
                }) rescue next
              end
            end
          end

          return nil
        end

        def self.get_leaf(base)
          if base.is_a?(Hash) and base.has_key?('children') and base['children'].is_a?(Array)
            return base['children'].collect{|i| get_leaf(i) }.flatten
          end

          if base['data']
            data = (MultiJson.load(base['data']) rescue base['data'])

            host = base['path'].split('/')[6]
            return nil unless host

            node = Asset.urlquery("name:aliases/#{host}").first
            hid = (node[:_id] rescue nil)
            return nil unless hid

            return {
              :id      => hid,
              :product => (base['path'].split('/')[4].strip rescue nil),
              :version => (data['revision'] rescue nil)
            }
          end

          nil
        end
      end
    end
  end
end

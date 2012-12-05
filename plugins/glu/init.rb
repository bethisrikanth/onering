require 'controller'
require 'assets/models/device'
require 'net/http'

module App
  class Base < Controller
    namespace '/api/glu' do
      get '/sync' do
        rv = []
        config = Config.get('glu/config')
        return 404 unless config && config['url']
        uri = URI.parse(config['url'])

        Net::HTTP.start(uri.host, uri.port) do |http|
          request = Net::HTTP::Get.new(uri.path)
          request.basic_auth config['username'], config['password'] if config['username'] && config['password']
          response = http.request(request)

          glu_json = JSON.parse(response.body)
          raise 'Invalid glu.json format' unless glu_json['entries']

          glu_agents = {}

          glu_json['entries'].each do |entry|
            raise "Invalid Glu agent name '#{entry['agent']}'" if entry['agent'].to_s.strip.chomp.empty?

          # initialize if necessary
            glu_agents[entry['agent']] = {} unless glu_agents[entry['agent']]
            glu_agents[entry['agent']]['apps'] = [] unless glu_agents[entry['agent']]['apps']
            glu_agents[entry['agent']]['tags'] = [] unless glu_agents[entry['agent']]['tags']

          # add app details
            app = {
              'name'          => (entry['metadata']['product'] rescue nil),
              'version'       => (entry['metadata']['version'] rescue nil),
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

          glu_agents.each do |name, glu_properties|
            device = Device.find_by_name(name)

            if device
              rv << device.id
              device['properties'] = {} unless device['properties']
              device['properties']['glu'] = glu_properties
              device.safe_save
            end
          end
        end

        Device.find(rv).to_json
      end
    end
  end
end

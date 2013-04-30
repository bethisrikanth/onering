require 'assets/models/device'
require 'salt/lib/helpers'

module Automation
  module Tasks
    module Salt
      class Run < Base
        include App::Helpers

        def run(request)
          rv = []
          plugin = opt!(:plugin)
          arguments = opt(:arguments, [])

          #fail("Arguments must be an array type") if arguments.empty?

          nodes = []
          nodes += Device.urlsearch(opt(:query)).fields('properties.site').to_a if opt(:query)
          nodes += Device.find([*opt(:nodes)].flatten).fields('properties.site').to_a if opt(:nodes)

          if nodes.empty?
            fail("No nodes specified")
          else
            log("Running Salt task #{plugin}(#{arguments.join(' ')}) on #{nodes.length} nodes")
          end

          begin

          # execute the command in each datacenter
            get_unique_sites(nodes).each do |site|
              saltrest_base = App::Config.get!("automation.saltrest.#{site.downcase}.url")

              if saltrest_base and not plugin.empty?
                saltrest = URI.parse("#{saltrest_base}/run/#{plugin}")

                log("Proxying command to #{saltrest.host}:#{saltrest.port}")
                http = Net::HTTP.new(saltrest.host, saltrest.port)

                request = Net::HTTP::Post.new(saltrest.request_uri)
                request['Content-Type'] = 'application/json'
                data = {
                  :nodes => nodes.collect{|i| i.id }
                }

                data[:arguments] = arguments unless arguments.empty?

              # perform the request
                request.body = MultiJson.dump(data)

                begin
                  body = http.request(request).body
                  rv  += MultiJson.load(body).reject{|k,v| v.to_s.empty? }.collect{|k,v| {k => v} }

                rescue Errno::ECONNREFUSED
                  log("Connection refused while attempting #{saltrest_base}", :error)

                rescue EOFError => e
                  log("Command failed: server closed connection before responding", :error)
                end
              end
            end



          rescue Exception => e
            log("Error executing remote command: #{e.class.name} - #{e.message}", :error)
            e.backtrace.each do |b|
              log("  #{b}", :error)
            end

            fail("Remote execution failed")
          end

          log("Received #{rv.length} responses")

          rv.each do |v|
            log("OUT: #{v}")
          end

          rv
        end
      end
    end
  end
end


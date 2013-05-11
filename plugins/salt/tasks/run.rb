require 'automation/models/request'
require 'assets/models/device'
require 'salt/lib/helpers'
require 'salt/lib/salt'

module Automation
  module Tasks
    module Salt
      class Run < Base
        include App::Helpers

        def run(request)
          api = {}
          results = {}
          site_nodes = {}
          proxied = 0
          rv = []
          plugin = opt!(:plugin)
          arguments = [*opt(:arguments, [])].collect{|i| [*i] }
          arguments = nil if arguments.empty?

          nodes = []
          nodes += Device.urlsearch(opt(:query)).fields('properties.site').to_a if opt(:query)
          nodes += Device.fields('properties.site').find([*opt(:nodes)].flatten).to_a if opt(:nodes)

          if nodes.empty?
            fail("No nodes specified")
          else
            log("Running Salt task #{plugin}(#{arguments.nil? ? '' : arguments.join(' ')}) on #{nodes.length} nodes")
          end

          begin
          # execute the command in each datacenter
            get_unique_sites(nodes).each do |site|
              begin
                api[site] = ::Salt::API.new(App::Config.get!("automation.saltrest.#{site.downcase}.url"))
              rescue ::App::ConfigKeyError => e
                log(e.message, :warn)
                next
              end

              if not plugin.empty?
                site_nodes[site] = nodes.select{|i| i.properties.get(:site) == site }.collect{|i| i.id }
                proxied += site_nodes[site].length

                begin
                  log("Proxying command to #{api[site].uri}, passing #{site_nodes[site].length} nodes")

                  code, results[site] = api[site].run(plugin, arguments, {
                    :async => true,
                    :nodes => site_nodes[site]
                  })

                rescue Errno::ECONNREFUSED
                  log("Connection refused while attempting #{saltrest_base}", :error)

                rescue EOFError => e
                  log("Command failed: server closed connection before responding", :error)
                end
              end
            end

            if (nodes.length-proxied) > 0
              log("Could not locate a Salt server for #{nodes.length-proxied} nodes. Please ensure all sites have a Salt configuration in config.yml")
            end

          rescue Exception => e
            log("Error executing remote command: #{e.class.name} - #{e.message}", :error)
            e.backtrace.each do |b|
              log("  #{b}", :error)
            end

            fail("Remote execution failed")
          end

          results.each do |site, response|
            api[site].results(response['job_id'], {
              :limit    => site_nodes[site].length,
              :max_wait => opt(:max_wait)
            }.compact) do |results|
              log("Got back #{results.length} results from #{site}...")
              results.each do |r|
                rv << {
                  :id          => r['id'],
                  :site        => site,
                  :plugin      => plugin,
                  :output      => r['return'][plugin],
                  :salt_job_id => r['jid']
                }
              end
            end
          end

          log("All results collected")
          rv
        end
      end
    end
  end
end


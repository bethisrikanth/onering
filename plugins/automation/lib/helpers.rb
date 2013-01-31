require 'uri'
require 'net/http'

module App
  module Helpers

    def get_unique_sites(devices)
      sites = []

      devices.each do |device|
        site = device.to_h.get('properties.site')
        sites << site if site and not sites.include?(site)
      end

      sites
    end

    def proxy_command_to_sites(devices, command, arguments=[])
      rv = {}

      get_unique_sites(devices).each do |site|
        saltrest_base = Config.get("automation.saltrest.#{site.downcase}.url")

        if saltrest_base and not command.empty?
          saltrest = URI.parse("#{saltrest_base}/run/#{command}")

          http = Net::HTTP.new(saltrest.host, saltrest.port)

          request = Net::HTTP::Post.new(saltrest.request_uri)
          request['Content-Type'] = 'application/json'
          data = {
            :nodes => devices.collect{|i| i.id }
          }

          data[:arguments] = arguments unless arguments.empty?

        # perform the request
          request.body = JSON.dump(data)

          rv[site.to_sym] = []

          begin
            rv[site.to_sym] << JSON.load(http.request(request).body).reject{|k,v| v.empty? }
          rescue Errno::ECONNREFUSED
            rv[site.to_sym] << {
              :errors => ["Connection refused while attempting #{saltrest_base}"]
            }
          end
        end
      end

      rv
    end
  end
end
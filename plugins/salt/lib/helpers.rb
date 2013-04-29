require 'uri'
require 'net/http'
require 'multi_json'

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
  end
end
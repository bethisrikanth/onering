require 'net/ping'
require 'rubyipmi'
require 'assets/models/asset'
require 'ipmi/lib/asset_extensions'

module Automation
  module Tasks
    module Ipmi
      class Execute < Task


        def self.perform(id, command, options={})
          node = Asset.find(id)
          fail("Cannot execute IPMI command on non-existent device #{id}") unless node
          fail("IPMI node extensions not properly loaded") unless node.respond_to?(:ipmi_command)

          if node.ipmi_command(command, options)
            info("IPMI command sent successfully")
          else
            fail("IPMI command failed")
          end
        end
      end
    end
  end
end

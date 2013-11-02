require 'set'
require 'assets/models/asset'
require 'assets/models/node_default'

module Automation
  module Tasks
    module Assets
      class Sync < Task
        def self.perform(*args)
          ids = Set.new()

        # resync defaults
          NodeDefault.urlquery('bool:enabled/true').each do |default|
            nodes = default.devices.to_a
            next unless nodes.length > 0

            info("Resyncing #{nodes.length} nodes with rule: #{default.name}")

          # add IDs to a set to ensure they only get synced once
            ids += nodes
          end

          if ids.empty?
            info("No devices required sync")

          else
            info("Adding #{ids.length} nodes to queue for resync")

            ids.each do |id|
            # queue this node
              run_low('assets/update', {
                :id => id
              }, true)
            end
          end
        end
      end
    end
  end
end
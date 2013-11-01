require 'set'
require 'assets/models/asset'
require 'assets/models/node_default'

module Automation
  module Tasks
    module Assets
      class UnsetField < Task
        def self.perform(field, query=nil)
          if query.nil?
            nodes = Asset.ids()
          else
            nodes = Asset.ids(query)
            abort("No nodes found for query #{query}") if nodes.empty?
          end

          field = field.split('.')
          field[-1] = '@'+field[-1]
          field = (['properties']+field).join('.')

          nodes.each do |id|
          # queue this node
            # run_low('assets/update', {
            #   'id' => id
            # }.set(field, nil))

            info({
              'id' => id
            }.set(field, nil).inspect)
          end
        end
      end
    end
  end
end
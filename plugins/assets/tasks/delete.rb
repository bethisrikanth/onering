require 'assets/models/device'

module Automation
  module Tasks
    module Assets
      class Delete < Base
        def run(request)
          rv = []
          nodes = []

          if opt(:query)
            nodes += Device.urlsearch(opt(:query)).to_a if opt(:query)
            log("Deleting #{nodes.length} nodes from query: #{opt(:query)}", :info)

          elsif opt(:nodes)
            n = opt(:nodes).split(/[\,\;\:\|]/)
            nodes += Device.find([*n]).to_a
            log("Deleting #{nodes.length} nodes explicitly named by ID", :info)
          end

          raise abort("No nodes specified") if nodes.empty?

          nodes.each do |node|
            begin
              id = node.id
              node.destroy()
              rv << id

            rescue Exception => e
              log("Error deleting node #{node.id}: #{e.class.name} - #{e.message}", :error)
              e.backtrace.each do |b|
                log("  #{b}", :debug)
              end

              next
            end
          end

          return rv
        end
      end
    end
  end
end

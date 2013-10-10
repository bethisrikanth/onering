require 'assets/models/asset'

module Automation
  module Tasks
    module Assets
      class Update < Base
        def run(request)
          rv = []
          nodes = []

          if opt(:query)
            nodes += Asset.urlsearch(opt(:query)).to_a if opt(:query)
            log("Updating #{nodes.length} nodes from query: #{opt(:query)}", :info)

          elsif opt(:nodes)
            n = opt(:nodes).flatten
            nodes += Asset.find([*n]).to_a

            log("Updating #{nodes.length} nodes explicitly named by ID", :info) unless nodes.empty?

            inserts = (n - nodes.collect{|i| i.id })

            if not inserts.empty?
              log("Inserting #{inserts.length} nodes explicitly named by ID", :info)

              inserts.each do |id|
                nodes << Asset.new({
                  :id => id
                })
              end
            end
          end

          raise abort("No nodes specified") if nodes.empty?

          nodes.each do |node|
            fail("Data is required for the update action") if @data.nil?

            begin
              if @data.is_a?(String)
                @data = MultiJson.load(@data)
              end

              if @data.is_a?(Hash)
                if @data['inventory'] === true
                  @data['collected_at'] = Time.now
                end

                node.from_h(@data)
              else
                fail("Data must be a JSON string or hash, got: #{@data.class.name}")
              end

              node.safe_save()
              node.reload()
              rv << node.to_h.get(opt(:field, 'id'))
            rescue Exception => e
              log("Error updating node #{node.id}: #{e.class.name} - #{e.message}", :error)
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

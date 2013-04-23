require 'assets/models/device'
require 'pp'

module Automation
  class AssetsTask < Task
    def run(request)
      rv = []

      if opt!(:action).to_sym == :list
        if opt(:query)
          query = Device.to_mongo(opt(:query))
        elsif opt(:nodes)
          query = Device.to_mongo("id/#{opt(:nodes).join('|')}}")
        end

        rv = Device.list(opt(:field, 'id'), query)

      else
        nodes = []

        if opt(:query)
          nodes += Device.urlsearch(opt(:query)).to_a if opt(:query)
        else
          nodes += Device.find([*opt(:nodes)]).to_a if opt(:nodes)
        end

        raise TaskAbort.new("No nodes specified") if nodes.empty?

        nodes.each do |node|
          case opt!(:action).to_sym
          when :update
            raise TaskFail.new("Data is required for the update action") if @data.nil?

            begin
              node.from_h(@data)
              node.safe_save()
              node.reload()
              rv += node.to_h.get(opt(:field, 'id'))
            rescue Exception => e
              error("Error updating node #{node.id}: #{e.class.name} - #{e.message}")
              next
            end

          when :delete
            begin
              node.destroy()

            rescue Exception => e
              error("Error deleting node #{node.id}: #{e.class.name} - #{e.message}")
              next
            end
          end
        end
      end

      return rv
    end
  end
end

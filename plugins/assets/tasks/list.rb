require 'assets/models/device'

module Automation
  module Tasks
    module Assets
      class List < Base
        def run(request)
          if opt(:query)
            query = Device.to_mongo(opt(:query))
          elsif opt(:nodes)
            query = Device.to_mongo("id/#{opt(:nodes).join('|')}}")
          end

          Device.list(opt(:field, 'id'), query)
        end
      end
    end
  end
end

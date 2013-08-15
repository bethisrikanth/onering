require 'assets/models/asset'

module Automation
  module Tasks
    module Assets
      class List < Base
        def run(request)
          if opt(:query)
            query = Asset.to_mongo(opt(:query))
          elsif opt(:nodes)
            query = Asset.to_mongo("id/#{opt(:nodes).join('|')}}")
          end

          Asset.list(opt(:field, 'id'), query)
        end
      end
    end
  end
end

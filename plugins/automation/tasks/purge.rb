require 'automation/models/job'

module Automation
  module Tasks
    module Auto
      class Purge < Base
        def run(request)
          requests = Automation::Request.where({
            :$or => [{
              :started_at => nil
            }, {
              :status => :succeeded
            }]
          }).to_a

          log("Purging #{requests.length} request records")

          requests.each do |request|
            request.destroy()
          end
        end
      end
    end
  end
end

require 'automation/models/job'

module Automation
  module Tasks
    module Auto
      class Nuke < Base
        def run(request)
          requests = Automation::Request.all.to_a

          log("Removing #{requests.length} request records")

          requests.each do |request|
            request.destroy()
          end
        end
      end
    end
  end
end

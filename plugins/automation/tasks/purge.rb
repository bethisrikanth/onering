require 'automation/models/job'

module Automation
  module Tasks
    module Auto
      class Purge < Base
        def run(request)
          requests = Automation::Request.search({
            :filter => {
              :or => [{
                :missing => {
                  :field     => :started_at,
                  :existence => true,
                  :null_value => false
                }
              }, {
                :term => {
                  :status => :succeeded
                }
              }]
            }
          })

          log("Purging #{requests.length} request records")

          requests.each do |request|
            request.destroy()
          end
        end
      end
    end
  end
end

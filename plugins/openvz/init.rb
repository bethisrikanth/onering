require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/openvz' do
      get '/sync' do
        output(Automation::Job.run_task('openvz.sync'))
      end
    end
  end
end

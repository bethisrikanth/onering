require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/xen' do
      get '/sync' do
        output(Automation::Job.run_task('xen.sync'))
      end
    end
  end
end

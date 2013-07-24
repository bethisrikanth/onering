require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/bind' do
      get '/sync' do
        output(Automation::Job.run_task('bind.sync'))
      end
    end
  end
end

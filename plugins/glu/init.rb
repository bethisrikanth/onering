require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/glu' do
      get '/sync' do
        output(Automation::Job.run_task('glu.sync'))
      end
    end
  end
end

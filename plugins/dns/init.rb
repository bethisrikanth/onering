require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/dns' do
      get '/sync' do
        output(Automation::Job.run_task('dns.sync'))
      end
    end
  end
end

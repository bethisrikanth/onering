require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/snmp' do
      get '/sync' do
        output(Automation::Job.run_task('snmp.sync'))
      end
    end
  end
end

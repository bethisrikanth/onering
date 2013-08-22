require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/snmp' do
      get '/sync' do
        output(Automation::Job.run_task('snmp.sync'))
      end

      get '/discover' do
        output(Automation::Job.run_task('snmp.discover'))
      end
    end
  end
end

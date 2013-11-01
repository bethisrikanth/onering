require 'controller'

module App
  class Base < Controller
    namespace '/api/snmp' do
      get '/sync' do
        queued = Automation::Tasks::Task.run('snmp/sync')
        return 500 unless queued
        return 200
      end

      get '/discover' do
        queued = Automation::Tasks::Task.run('snmp/discover')
        return 500 unless queued
        return 200
      end
    end
  end
end

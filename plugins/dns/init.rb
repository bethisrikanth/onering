require 'controller'

module App
  class Base < Controller
    namespace '/api/dns' do
      get '/sync' do
        queued = Automation::Tasks::Task.run_low('dns/sync')
        return 500 unless queued
        return 200
      end
    end
  end
end

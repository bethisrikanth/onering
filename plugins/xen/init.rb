require 'controller'

module App
  class Base < Controller
    namespace '/api/xen' do
      get '/sync' do
        queued = Automation::Tasks::Task.run_low('xen/sync')
        return 500 unless queued
        return 200
      end
    end
  end
end
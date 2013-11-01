require 'controller'

module App
  class Base < Controller
    namespace '/api/glu' do
      get '/sync' do
        queued = Automation::Tasks::Task.run('glu/sync')
        return 500 unless queued
        return 200
      end
    end
  end
end

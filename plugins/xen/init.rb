require 'controller'
require 'automation/models/job'

module App
  class Base < Controller
    namespace '/api/xen' do
      get '/sync' do
      end
    end
  end
end

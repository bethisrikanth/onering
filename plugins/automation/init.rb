require 'controller'
require 'assets/models/device'
require 'automation/models/job'
require 'automation/lib/helpers'

module App
  class Base < Controller
    include Helpers

    helpers do
      Automation::Task.load_all()
    end

    namespace '/api/automation' do
      get '/test' do
        output(Automation::Job.find_by_name('tester').request())
      end

      namespace '/jobs' do
        get '/waiting' do
          output(Automation::Request.where({
            :finished => false
          }).to_a.collect{|i|
            i.to_h
          })
        end
      end
    end
  end
end

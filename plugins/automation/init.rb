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

      namespace '/jobs' do
        get '/requeue/:id' do
          job_request = Automation::Request.find(params[:id])
          return 404 unless job_request

          output(job_request.job.request(job_request.to_h))
        end

        get '/waiting' do
          output(Automation::Request.where({
            :finished => false
          }).to_a.collect{|i|
            i.to_h
          })
        end


        get '/run/:name' do
          output(Automation::Job.find_by_name(params[:name]).request({
            :parameters => (request.env['rack.request.query_hash'] || {})
          }))
        end
      end
    end
  end
end

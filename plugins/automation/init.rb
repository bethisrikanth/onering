require 'controller'
require 'assets/models/device'
require 'automation/models/job'
require 'automation/lib/helpers'

module App
  class Base < Controller
    include Helpers

    helpers do
      Automation::Tasks::Base.load_all()
    end

    namespace '/api/automation' do
      namespace '/requests' do
        get '/summary/*' do
          job_requests = (
            params[:q].nil? ? Automation::Request.all
            : Automation::Request.where(Device.to_mongo(params[:q]))
          ).collect{|i|
            i.to_h
          }

          output(job_requests.count_distinct(params[:splat].first.split('/')))
        end

        get '/status/:status' do
          case params[:status].to_sym
          when :pending then
            job_requests = Automation::Request.where({
              :started_at => nil
            })
          when :unfinished then
            job_requests = Automation::Request.where({
              :finished_at => nil
            })
          else
            job_requests = Automation::Request.where({
              :status => params[:status]
            })
          end

          output(job_requests.to_a.collect{|i|
            i.to_h
          })
        end

      # flush pending jobs from the queue
        get '/flush' do
          rv = {
            :removed => 0,
            :time    => Time.now
          }

          job_requests = Automation::Request.where({
            :started_at => nil
          })

          job_requests.each do |jr|
            jr.destroy()
            rv[:removed] += 1
          end

          rv[:time] = (Time.now - rv[:time]).to_f
          output(rv)
        end

        get '/requeue' do
          rv = []
          job_requests = Automation::Request.where({
            :status => :queue_failed
          })

          job_requests.each do |jr|
            rv << jr.job.request(jr.to_h)
            jr.destroy()
          end

          output(rv)
        end

        get '/:id/requeue' do
          job_request = Automation::Request.find(params[:id])
          return 404 unless job_request
          rv = job_request.job.request(job_request.to_h)
          job_request.destroy()
        end

        get '/:id' do
          job_request = Automation::Request.find(params[:id])
          return 404 unless job_request
          output(job_request)
        end
      end

      namespace '/jobs' do
        get '/:name/waiting' do
          job = Automation::Job.find_by_name(params[:name])
          return 404 unless job
          output(job.requests)
        end

        get '/:name/run' do
          output(Automation::Job.find_by_name(params[:name]).request({
            :parameters => (request.env['rack.request.query_hash'] || {})
          }))
        end

        post '/:name/run' do
          output(Automation::Job.find_by_name(params[:name]).request({
            :parameters => (request.env['rack.request.query_hash'] || {}),
            :data => request.env['rack.input'].read
          }))
        end

        get '/:name' do
        end
      end

      namespace '/tasks' do
        get '/:name/run' do
          output(Automation::Job.run_task(params[:name], {
            :parameters => request.env['rack.request.query_hash']
          }.compact))
        end
      end
    end
  end
end

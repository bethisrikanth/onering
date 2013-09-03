require 'controller'
require 'assets/models/asset'
require 'automation/models/job'

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
            : Automation::Request.urlquery(params[:q])
          ).collect{|i|
            i.to_hash
          }

          output(job_requests.count_distinct(params[:splat].first.split('/')))
        end

        get '/status/:status' do
          case params[:status].to_sym
          when :pending then
            job_requests = Automation::Request.urlquery("started_at/null")
          when :unfinished then
            job_requests = Automation::Request.urlquery("finished_at/null")
          else
            job_requests = Automation::Request.urlquery("status/#{params[:status]}")
          end

          output(job_requests.collect{|i|
            i.to_hash
          })
        end

      # flush pending jobs from the queue
        get '/flush' do
          rv = {
            :removed => 0,
            :time    => Time.now
          }

          job_requests = Automation::Request.urlquery("started_at/null")

          job_requests.each do |jr|
            jr.destroy()
            rv[:removed] += 1
          end

          rv[:time] = (Time.now - rv[:time]).to_f
          output(rv)
        end

        get '/requeue' do
          rv = []
          job_requests = Automation::Request.urlquery("status/queue_failed")

          job_requests.each do |jr|
            rv << jr.job.request(jr.to_hash)
            jr.destroy()
          end

          output(rv)
        end

      # remove all successful jobs from the database
        get '/purge' do
          output(Automation::Job.run_task('auto.purge'))
        end

      # remove everything from the database
        get '/nuke' do
          output(Automation::Job.run_task('auto.nuke'))
        end

        get '/:id/requeue' do
          job_request = Automation::Request.find_by_id(params[:id])
          return 404 unless job_request
          rv = job_request.job.request(job_request.to_hash)
          job_request.destroy()
        end

        get '/:id' do
          job_request = Automation::Request.find_by_id(params[:id])
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

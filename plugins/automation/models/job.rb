require 'queue'
require 'model'
require 'msgpack'
require 'deep_merge'
require 'automation/models/request'
require 'automation/lib/task'

module Automation
  class JobTermination  < Exception; end
  class TaskTermination < Exception; end

  class JobAbort  < JobTermination; end
  class JobRetry  < JobTermination; end
  class JobFail   < JobTermination; end
  class TaskAbort < TaskTermination; end
  class TaskRetry < TaskTermination; end
  class TaskFail  < TaskTermination; end
  class TaskJump  < TaskTermination; end



  class Job < App::Model::Elasticsearch
    index_name "automation_jobs"

    field :name,       :string, :unique => true
    field :parameters, :object
    field :tasks,      :object, :array => true
    field :data,       :string
    field :created_at, :date,   :default => Time.now
    field :updated_at, :date,   :default => Time.now


    def requests()
      Request.urlquery("job_id/#{self.id}")
    end

    def request(options={})
    # generate unique request with specific details
      request = Request.new({
        :status     => :unqueued,
        :anonymous  => options[:anonymous],
        :tasks      => (options[:anonymous].nil? ? nil : self.tasks),
        :job_id     => self.id,
        :source     => options[:source],
        :parameters => (options[:parameters] || {}),
        :user       => options[:user]
      }.compact)
      request.save()

      raise "Unable to generate job request" unless request

    # attempt to enqueue job request
      result = (App::Queue.channel(options.get(:queue, 'onering')).push({
        :job_id     => self.id.to_s,
        :request_id => request.id.to_s,
        :anonymous  => options[:anonymous],
        :tasks      => (options[:anonymous].nil? ? nil : self.tasks),
        :source     => request.source,
        :parameters => request.parameters,
        :created_at => request.created_at.strftime("%Y-%m-%d %H:%M:%S %z"),
        :data       => (options[:data] ? options[:data].to_msgpack : nil)
      }.compact) rescue false)

    # update request with status
      request.status = (result === false ? :queue_failed : :queued)
      request.save()

    # return IDs and statuses
      if result
        App::Log.increment("worker.requests.queued")

        return ({
          :request_id => request.id.to_s,
          :job_id     => self.id.to_s,
          :queue_id   => result[:id],
          :status     => (
            case result[:status].downcase.to_sym
            when :inserted then :queued
            else result[:status].downcase.to_sym
            end
          ),
          :body     => result[:body]
        }.compact)
      else
        App::Log.increment("worker.requests.queuefail")

        return ({
          :request_id => request.id.to_s,
          :job_id     => self.id.to_s,
          :status     => :queue_failed
        })
      end
    end


    class<<self
      def abort(message)
        raise JobAbort.new(message)
      end

      def fail(message)
        raise JobFail.new(message)
      end

      def log(message, severity=:info)
        STDOUT.puts("[JOB] #{message}")
      end

      def run_task(name, options={})
        Automation::Job.new({
          :id         => 'anonymous',
          :tasks      => [{
            :type => name
          }]
        }).request({
          :anonymous  => true,
          :parameters => options[:parameters],
          :data       => options[:data]
        }.compact)
      end

      def run(header)
        require 'rainbow'

        begin
          fail("Request is missing a Job ID")     unless header['job_id']
          fail("Request is missing a Request ID") unless header['request_id']

        # get request
          # request = Request.find(header['request_id'])
          # fail("Cannot find Request ID #{header['request_id']}") unless request

          # request.started_at = Time.now
          # request.status     = :running
          # request.save()


        # get job
          if header['anonymous'] === true
            job = Job.new({
              :id    => header['job_id'],
              :tasks => header['tasks']
            })
          else
            job = Job.find_by_id(header['job_id'])
            fail("Cannot find Job ID #{header['job_id']}") unless job
          end

        # merge header data with current job
          # if job.parameters and not request.parameters.empty?
          #   header['parameters'] = job.parameters.deep_merge!(request.parameters)
          # end


        # initial data is either provided in the request or inherited from the job definition
          last_task_result = (header['data'].nil? ? job.data : MessagePack.unpack(header['data']))

        # tell someone we tried to do dumb things
          abort("Job has no tasks defined, skipping") if job.tasks.empty?


        # process tasks
          job.tasks.each do |config|
          # merge data from header parameters into first task configuration
            if config === job.tasks.first
              config['parameters'] = config.get('parameters',{}).deep_merge!(header.get('parameters',{}))
            end

          # build task instance
            fail("Task configuration requires a type field") unless config['type']
            task = (config['type'].split('.').inject(Automation::Tasks){|k,name| k = k.const_get(name.capitalize) }).new(config['parameters'])
            fail("No such task of type '#{config['type']}'") unless task

          # execute task
            begin
              task_started_at = Time.now
              results = []

            # data is a flattened, compacted array consisting of:
            # * data inherited from the job level, overridden by...
            # * data inherited from the output of the last task
            #
              data = [*last_task_result].flatten.compact

              App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.started")

              if data.empty?
                log("Starting #{config['type']} task")
              else
                log("Starting #{config['type']} task with #{data.length} data elements")
                App::Log.gauge("worker.tasks.#{config['type'].gsub('.','-')}.data_elements", data.length)
              end

            # no data specified, run the task once
              if data.empty?
                results << task.execute(header)

            # iterate through all input data, running the task once for each
            # piece of data
              else
                data.each do |datum|
                  results << task.execute(header, datum)
                end
              end

            # push the result data into the request object
              # request.push(:results, {
              #   :task   => config['type'],
              #   :output => results
              # }, :none)

            # set next input to current result(s)
              last_task_result = results

            # log task runtime
              App::Log.timing("worker.tasks.#{config['type'].gsub('.','-')}.runtime", ((Time.now.to_f - task_started_at.to_f) * 1000.0))
              App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.succeeded")

          # task aborted, continue to next task
            rescue TaskAbort => e
              log("[Task Aborted] #{e.message}", :warning)
              App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.aborted")
              next

          # task requested a retry
            rescue TaskRetry => e
              config['retry_limit']  ||= 5
              config['retry_number'] ||= 0
              config['retry_number']  += 1

              if config['retry_number'] <= config['retry_limit']
                log("[Task Retrying] (#{config['retry_number']}/#{config['retry_limit']}) #{e.message}", :warning)
                App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.retries")
                retry
              else
                log("[Task Failed] Too many retries (attempted #{config['retry_number']})", :error)
                App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.failed")
                last_task_result = nil
                next
              end

          # task has failed, proceed to next task with null input
            rescue TaskFail => e
              log("[Task Failed] #{e.message}", :error)
              last_task_result = nil
              App::Log.increment("worker.tasks.#{config['type'].gsub('.','-')}.failed")
              next
            end

          end

        # we got here! success!
          # request.finished_at = Time.now
          # request.status      = :succeeded
          # request.save()

          return last_task_result

        rescue JobAbort => e
          if request
            request.finished_at = Time.now
            request.status      = :aborted
            request.save()
          end

          raise e

        rescue JobRetry => e
          if request
            request.status = :retrying
            request.save()
          end

          raise e

        rescue Exception => e
          if request
            request.finished_at = Time.now,
            request.status      = :failed
            request.save()
          end


          raise e
        end
      end
    end
  end
end
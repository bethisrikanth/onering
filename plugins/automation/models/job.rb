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

  class Job < App::Model::Base
    set_collection_name "automation_jobs"

    timestamps!

    key :name,       String, :unique => true
    key :parameters, Hash
    key :tasks,      Array
    key :data

    def request(options={})
    # generate unique request with specific details
      request = Request.create({
        :status     => :unqueued,
        :job_id     => self.id,
        :source     => options[:source],
        :parameters => (options[:parameters] || {}),
        :user       => options[:user]
      }.compact)

      raise "Unable to generate job request" unless request

    # attempt to enqueue job request
      result = (App::Queue.channel('onering').push({
        :job_id     => self.id.to_s,
        :request_id => request.id.to_s,
        :source     => request.source,
        :parameters => request.parameters,
        :created_at => request.created_at.strftime("%Y-%m-%d %H:%M:%S %z"),
        :data       => (options[:data] ? options[:data].to_msgpack : nil)
      }.compact) rescue false)

    # update request with status
      request.set({
        :status => (result === false ? :queue_failed : :queued)
      })

    # return IDs and statuses
      if result
        return ({
          :id       => request.id.to_s,
          :job_id   => self.id.to_s,
          :queue_id => result[:id],
          :status   => result[:status].downcase,
          :body     => result[:body]
        }.compact)
      else
        return ({
          :id       => request.id.to_s,
          :job_id   => self.id.to_s,
          :status   => :queue_failed
        })
      end
    end


    class<<self
      def run(header, logger=STDERR)
        require 'rainbow'

        begin
          raise JobFail.new("Request is missing a Job ID")     unless header['job_id']
          raise JobFail.new("Request is missing a Request ID") unless header['request_id']

        # get request
          request = Request.find(header['request_id'])
          raise JobFail.new("Cannot find Request ID #{header['request_id']}") unless request
          request.set(:status => :running)

        # get job
          job = Job.find(header['job_id'])
          raise JobFail.new("Cannot find Job ID #{header['job_id']}") unless job

        # merge header data with current job
          if job.parameters and not request.parameters.empty?
            header['parameters'] = job.parameters.deep_merge!(request.parameters)
          end

        # initial data is either provided in the request or inherited from the job definition
          last_task_result = (header['data'].nil? ? job.data : MessagePack.unpack(header['data']))

        # tell someone we tried to do dumb things
          raise JobAbort.new("Job has no tasks defined, skipping") if job.tasks.empty?


        # process tasks
          job.tasks.each do |config|
          # merge data from header parameters into first task configuration
            if config === job.tasks.first
              config['parameters'] = config['parameters'].deep_merge!(header['parameters'])
            end

          # build task instance
            raise JobFail.new("Task configuration requires a type field") unless config['type']
            task = (Automation.const_get("#{config['type'].capitalize}Task").new(config['parameters']) rescue nil)
            raise JobFail.new("No such task of type '#{config['type']}'") unless task

          # execute task
            begin
              results = []

            # data is a flattened, compacted array consisting of:
            # * data inherited from the job level, overridden by...
            # * data inherited from the output of the last task
            #
              data = [*last_task_result].flatten.compact

              logger.puts("Starting #{config['type']} task with #{data.length} data elements")

            # no data input, just run the task
              if data.empty?
                results << task.execute(header)

            # iterate through all input data, running the task once for each
            # piece of data
              else
                data.each do |datum|
                  task.data = datum
                  results << task.execute(header)
                end
              end

            # set next input to current result(s)
              last_task_result = results

          # task aborted, continue to next task
            rescue TaskAbort => e
              logger.puts("[Task Aborted] #{e.message}".foreground(:yellow))
              next

          # task requested a retry
            rescue TaskRetry => e
              config['retry_limit']  ||= 5
              config['retry_number'] ||= 0
              config['retry_number']  += 1

              if config['retry_number'] <= config['retry_limit']
                logger.puts("[Task Retrying] (#{config['retry_number']}/#{config['retry_limit']}) #{e.message}".foreground(:yellow))
                retry
              else
                logger.puts("[Task Failed] Too many retries (attempted #{config['retry_number']})".foreground(:red))
                last_task_result = nil
                next
              end

          # task has failed, proceed to next task with null input
            rescue TaskFail => e
              logger.puts("[Task Failed] #{e.message}".foreground(:red))
              last_task_result = nil
              next
            end
          end

        # we got here! success!
          request.set({
            :finished => true,
            :status   => :succeeded
          })

          return last_task_result

        rescue JobAbort => e
          request.set({
            :finished => true,
            :status   => :aborted
          }) if request

          raise e

        rescue JobRetry => e
          request.set({
            :finished => true,
            :status   => :retrying
          }) if request

          raise e

        rescue Exception => e
          request.set({
            :finished => true,
            :status   => :failed
          }) if request

          raise e

        end
      end
    end
  end
end
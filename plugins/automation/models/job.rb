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

    def requests()
      Request.where({
        :job_id => self.id
      })
    end

    def request(options={})
    # generate unique request with specific details
      request = Request.create({
        :status     => :unqueued,
        :anonymous  => options[:anonymous],
        :tasks      => (options[:anonymous].nil? ? nil : self.tasks),
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
        :anonymous  => options[:anonymous],
        :tasks      => (options[:anonymous].nil? ? nil : self.tasks),
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
          request = Request.find(header['request_id'])
          fail("Cannot find Request ID #{header['request_id']}") unless request
          request.set({
            :started_at => Time.now,
            :status     => :running
          })


        # get job
          if header['anonymous'] === true
            job = Job.new({
              :id    => header['job_id'],
              :tasks => header['tasks']
            })
          else
            job = Job.find(header['job_id'])
            fail("Cannot find Job ID #{header['job_id']}") unless job
          end

        # merge header data with current job
          if job.parameters and not request.parameters.empty?
            header['parameters'] = job.parameters.deep_merge!(request.parameters)
          end


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
              results = []

            # data is a flattened, compacted array consisting of:
            # * data inherited from the job level, overridden by...
            # * data inherited from the output of the last task
            #
              data = [*last_task_result].flatten.compact

              if data.empty?
                log("Starting #{config['type']} task")
              else
                log("Starting #{config['type']} task with #{data.length} data elements")
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
              request.push(:results => {
                :task   => config['type'],
                :output => results
              })

            # set next input to current result(s)
              last_task_result = results

          # task aborted, continue to next task
            rescue TaskAbort => e
              log("[Task Aborted] #{e.message}", :warning)
              next

          # task requested a retry
            rescue TaskRetry => e
              config['retry_limit']  ||= 5
              config['retry_number'] ||= 0
              config['retry_number']  += 1

              if config['retry_number'] <= config['retry_limit']
                log("[Task Retrying] (#{config['retry_number']}/#{config['retry_limit']}) #{e.message}", :warning)
                retry
              else
                log("[Task Failed] Too many retries (attempted #{config['retry_number']})", :error)
                last_task_result = nil
                next
              end

          # task has failed, proceed to next task with null input
            rescue TaskFail => e
              log("[Task Failed] #{e.message}", :error)
              last_task_result = nil
              next
            end
          end

        # we got here! success!
          request.set({
            :finished_at => Time.now,
            :status      => :succeeded
          })

          return last_task_result

        rescue JobAbort => e
          request.set({
            :finished_at => Time.now,
            :status      => :aborted
          }) if request

          raise e

        rescue JobRetry => e
          request.set({
            :status   => :retrying
          }) if request

          raise e

        rescue Exception => e
          request.set({
            :finished_at => Time.now,
            :status      => :failed
          }) if request

          raise e

        end
      end
    end
  end
end
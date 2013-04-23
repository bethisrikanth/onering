require 'queue'
require 'model'
require 'msgpack'
require 'automation/models/request'
require 'automation/lib/task'

module Automation
  class JobAbort  < Exception; end
  class JobRetry  < Exception; end
  class JobFail   < Exception; end
  class TaskAbort < Exception; end
  class TaskRetry < Exception; end
  class TaskFail  < Exception; end
  class TaskJump  < Exception; end

  class Job < App::Model::Base
    set_collection_name "automation_jobs"

    timestamps!

    key :name,       String, :unique => true
    key :parameters, Hash
    key :tasks,      Array

    def request(options={})
    # generate unique request ID with specific details
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
      def run(header)
        raise JobFail.new("Request is missing a Job ID")     unless header['job_id']
        raise JobFail.new("Request is missing a Request ID") unless header['request_id']

      # get request
        request = Request.find(header['request_id'])
        raise JobFail.new("Cannot find Request ID #{header['request_id']}")
        request.set(:status => :runnable)

      # get job
        job = Job.find(header['job_id'])
        raise JobFail.new("Cannot find Job ID #{header['job_id']}")

      # merge header data with current job
        #header = header.

        last_task_result = nil

      # process tasks
        job.tasks.each do |type|
          task = Task.find_by_name(type)
          raise JobFail.new("No such task of type '#{type}'") unless task

          task.run(header, last_task_result)
        end
      end
    end
  end
end
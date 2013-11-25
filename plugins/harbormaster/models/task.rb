require 'model'

module Harbormaster
  class Task < App::Model::Elasticsearch
    index_name "harbormaster_tasks"

    field :name,       :string
    field :cluster,    :string
    field :enabled,    :boolean,  :default => true
    field :instances,  :integer
    field :task,       :object,   :default => {}
    field :resources,  :object,   :default => {}
    field :scaling,    :object,   :default => ({
      :mode          => :static,
      :fail_behavior => 'nothing',
      :config        => {}
    })

    field :created_at,      :date,      :default => Time.now
    field :updated_at,      :date,      :default => Time.now
    field :last_checked_at, :date
    field :last_scaled_at,  :date


  # dynamic_scaling_instance_count
  #
  # if scaling mode=dynmamic, this will perform the configured check to retrieve
  # to calculate what the current number of active instances should be for this
  # task
  #
    def dynamic_scaling_instance_count()

    end

  # scale
  #
  # will dispatch the requested scaling state (including resource utilization changes)
  # to the associated cluster
  #
    def scale()
    # verify connectivity to the compute cluster


    # build the request

    # send request
    end
  end
end
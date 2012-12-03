require 'model'

class DeviceStat < App::Model::Base
  include App::Model::Taggable

  set_collection_name "metrics"

  timestamps!

  key :metrics, Hash
end

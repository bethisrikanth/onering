require 'yaml'
require 'hashlib'
require 'model'

class Configuration < App::Model::Elasticsearch
  index_name "configuration"

  field :key,            :string,  :index => :not_analyzed
  field :enabled,        :boolean, :default => true
  field :value_object,   :object
  field :value_string,   :string
  field :value_number,   :float
  field :value_boolean,  :boolean
  field :value_date,     :date

  before_destroy :_unregister_config


  def value=(data)
    if data.nil?
      _set_value_type(nil, nil)
    else
      if data.is_a?(Hash)
        _set_value_type(:object, data)
      elsif data.is_a?(Numeric)
        if data.is_a?(Integer)
          _set_value_type(:number, data.to_i)
        else
          _set_value_type(:number, data)
        end
      elsif data.is_a?(TrueClass) or data.is_a?(FalseClass)
        _set_value_type(:boolean, data)
      elsif data.is_a?(Date) or data.is_a?(Time)
        _set_value_type(:date, data)
      else
        _set_value_type(:string, data.to_s)
      end
    end
  end

  def value()
    %w{
      date
      object
      number
      boolean
      string
    }.each do |type|
      rv = self.send(:"value_#{type}")
      return rv unless rv.nil?
    end

    return nil
  end


  def _set_value_type(type, data)
    self.value_object  = nil
    self.value_string  = nil
    self.value_number  = nil
    self.value_date    = nil
    self.value_boolean = nil

  # without a type, just leave everything erased
    unless type.nil?
      self.send(:"value_#{type}=", data)
    end
  end

  def _unregister_config()
    App::Config.unregister(self.id)
    return true
  end

  class<<self
    def sync_remote_with_local()
      @_keyversions ||= {}

      config_headers = Configuration.search({
        :version => true,
        :size    => App::Config.get('global.configuration.remote.max_results', 1000),
        :fields  => [],
        :filter   => {
          :terms => {
            :enabled => [true]
          }
        }
      },{
        :raw => true
      })

      return false unless config_headers.is_a?(Hash)
      return false unless config_headers.get('hits.hits').is_a?(Array)

      config_headers.get('hits.hits').each do |header|
        @_keyversions[header['_id']] ||= 0

        if header['_version'].to_i > @_keyversions[header['_id']]
          c = Configuration.find(header['_id'])
          next if c.value.nil?

          @_keyversions[c.id] = c.metadata(:version)
          Onering::Logger.debug("Registering external configuration path #{c.key} (version #{@_keyversions[c.id]}) to path #{c.key}")
          App::Config.register(c.id, c.key, c.value)
        end
      end

    # unregister deleted configurations
      (@_keyversions.keys - config_headers.get('hits.hits').collect{|i| i['_id'] }).each do |missing_id|
        Onering::Logger.debug("Unregistering missing external configuration #{missing_id}")
        App::Config.unregister(missing_id)
        @_keyversions.delete(missing_id)
      end
    end
  end
end

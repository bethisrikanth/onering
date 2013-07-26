require 'set'
require 'model'
require 'assets/models/device'

module Hardware
  class Rack < App::Model::Base
    set_collection_name "hardware_racks"

    timestamps!

    key :name,      String, :required => true
    key :site,      String
    key :vendor,    Hash
    key :height,    Integer, :required => true


    def units()
      devices = Device.urlsearch("site/#{self.site}/rack/#{self.name}/virtual/not:true").to_a
      seen = Set.new()

      rv = []

      (1..self.height).to_a.reverse.collect do |u|
        nodes = devices.select{|i| [*i.properties.get(:unit, 0)].include?(u) }
        device_units = nodes.collect{|i| [*i.properties.get(:unit, 1)] }.flatten

        unless seen.include?(u)
          seen += device_units

          unit = device_units.sort.reverse.uniq
          height = (unit.empty? ? 1 : (unit.max - unit.min) + 1)
          make  = nodes.collect{|i| i.properties.get(:make) }.uniq
          model = nodes.collect{|i| i.properties.get(:model) }.uniq

          unit = (unit.empty? ? [u] : unit)
          height = (height == 0 ? 1 : height)
          make = make.first if make.length == 1
          model = model.first if model.length == 1

          rv << {
            :unit     => unit,
            :height   => height,
            :make     => make.nil_empty,
            :model    => model.nil_empty,
            :physical => (nodes.reject{|i| i.properties.get(:physical).nil? }.first.to_h || {}).get('properties.physical'),
            :nodes    => nodes.collect{|i|
              i.to_h.reject{|k,v| k == 'properties'}.merge({
                :properties => {
                  :slot     => i.properties.get(:slot)
                }
              })
            }.sort{|a,b| a[:properties][:slot] <=> b[:properties][:slot] }.nil_empty
          }.compact
        end
      end

      rv
    end

    def serializable_hash(options = {})
      super(options).merge({
        :units => self.units()
      })
    end
  end
end
require 'set'
require 'model'
require 'assets/models/device'
require 'organization/models/contact'

module Hardware
  class Rack < App::Model::Base
    set_collection_name "hardware_racks"

    timestamps!

    key :name,      String, :required => true
    key :site,      String
    key :vendor,    Hash
    key :height,    Integer, :required => true


    def units()
      devices = Device.urlsearch("str:site/#{self.site}/str:rack/#{self.name}/virtual/not:true").to_a
      seen = Set.new()

      rv = []


      (1..self.height).to_a.reverse.collect do |u|
        nodes = devices.select{|i| [*i.properties.get(:unit, 0)].map(&:to_i).include?(u) }
        physical = (nodes.reject{|i| i.properties.get(:physical).nil? }.first.to_h || {}).get('properties.physical',{})

        if physical.get('layout.height')
          node_units = ((u - physical.get('layout.height').to_i + 1)..u).to_a
        else
          node_units = nodes.collect{|i| [*i.properties.get(:unit, 0)] }.flatten.collect{|i| i.to_i }
        end

        unless seen.include?(u)
          seen += node_units

        # Hax: extract values from things
          unit = node_units.sort.reverse.uniq
          height = (unit.empty? ? 1 : (unit.max - unit.min) + 1)
          make  = nodes.collect{|i| i.properties.get(:make) }.uniq
          model = nodes.collect{|i| i.properties.get(:model) }.uniq

        # Hax II: normalize them
          unit = (unit.empty? ? [u] : unit)
          height = (height == 0 ? 1 : height)
          make = make.first if make.length == 1
          model = model.first if model.length == 1
          slots = {}

        # create slot objects keyed on slot number
          nodes.each{|i|
            slots[i.properties.get(:slot, 0)] = i.to_h.reject{|k,v| k == 'properties'}.merge({
              :empty      => false,
              :properties => {
                :slot        => i.properties.get(:slot),
                :alert_state => i.properties.get(:alert_state)
              }.compact
            })
          }

          rack_nodes = (1..physical.get('layout.slots.count', 0)).to_a.collect{|i|
            slots[i] || {
              :empty => true,
              :properties => {
                :slot => i
              }
            }
          }

          rack_nodes = slots.values if rack_nodes.empty?


        # push rack object onto rack
          rv << {
            :unit     => unit,
            :height   => height,
            :make     => (make.nil? ? nil : make.nil_empty),
            :model    => (model.nil? ? nil : model.nil_empty),
            :physical => physical,
            :nodes    => rack_nodes.sort{|a,b| a.get('properties.slot') <=> b.get('properties.slot') }.nil_empty
          }.compact
        end
      end

      rv
    end

    def serializable_hash(options = {})
      contact_id = self.vendor.get('contact_id')
      contact = Contact.find(contact_id).to_h if contact_id

      super(options).deep_merge!({
        'units' => self.units(),
        'vendor' => {
          'contact' => contact
        }
      }.compact)
    end
  end
end
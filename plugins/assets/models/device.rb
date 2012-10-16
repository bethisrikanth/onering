require 'model'

class Device < App::Model::Base
  set_collection_name "devices"

  before_validation :_mangle_id
  validate :_id_pattern_valid?

  many :devices
  timestamps!
  
  key :name,       String
  key :tags,       Array
  key :properties, Hash


  private
    def _mangle_id
      id = id.strip.downcase if id
    end

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end
end
require 'model'

class Device < App::Model::Base
  include App::Model::Taggable

  set_collection_name "devices"

  before_validation :_mangle_id
  validate :_id_pattern_valid?

  timestamps!

  key :name,            String
  key :properties,      Hash
  key :user_properties, Hash
  key :tags,            Array

  private
    def _mangle_id
      id = id.strip.downcase if id
    end

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end
end
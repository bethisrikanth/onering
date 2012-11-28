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
  key :collected_at,    Time

  def add_note(body, id=nil)
    id = Time.now.to_i if not id or (id.to_i == 0)
    id = id.to_s

    if properties
      properties['notes'] = {} unless properties['notes']
      now = Time.now

      if properties['notes'][id]
        note = properties['notes'][id]
      else
        note = {
          'created_at' => now
        }
      end

      note['body'] = body
      note['updated_at'] = now

      properties['notes'][id] = note
      return true
    end

    false
  end

  private
    def _mangle_id
      id = id.strip.downcase if id
    end

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end
end
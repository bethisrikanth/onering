require 'model'
require 'assets/models/device_stat'

class Device < App::Model::Base
  VALID_STATUS = ['online', 'fault', 'maintenance', 'allocatable']
  MANUAL_STATUS = ['fault', 'maintenance', 'available']

  include App::Model::Taggable

  set_collection_name "devices"

  before_validation :_mangle_id
  before_validation :_confine_status
  validate :_id_pattern_valid?

  timestamps!

  key :name,            String
  key :properties,      Hash
  key :user_properties, Hash
  key :tags,            Array
  key :aliases,         Array
  key :collected_at,    Time
  key :status,          String

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

    def _confine_status
      if self.status_changed?
        if not VALID_STATUS.include?(self.status)
          errors.add(:status, "Status must be one of #{VALID_STATUS.join(', ')}")
        end

      # automatic collection cannot clear a fault, maintenance, or available state
        if MANUAL_STATUS.include?(self.status_was)
          if self.collected_at_changed?
            self.status = self.status_was
          end
        end
      end
    end

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end
end

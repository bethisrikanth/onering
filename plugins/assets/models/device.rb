require 'model'
require 'assets/models/device_stat'
require 'assets/lib/helpers'

class Device < App::Model::Base
  include App::Model::Taggable

  VALID_STATUS = ['online', 'fault', 'allocatable', 'reserved', 'provisioning', 'installing']
  MANUAL_STATUS = ['fault', 'allocatable', 'reserved']
  NO_AUTOCLEAR_STATUS = ['provisioning', 'installing']
  VALID_MAINT_STATUS = ['parts', 'service']

  set_collection_name "devices"

  before_validation :_mangle_id
  before_validation :_confine_status
  before_validation :_confine_maintenance_status
  before_save       :_compact
#  validate          :_id_pattern_valid?

  timestamps!

  key :name,               String
  key :parent_id,          String
  key :properties,         Hash
  key :user_properties,    Hash
  key :tags,               Array
  key :aliases,            Array
  key :collected_at,       Time
  key :status,             String
  key :maintenance_status, String

  def add_note(body, user_id)
    id = Time.now.to_i.to_s

    if properties
      properties['notes'] = {} unless properties['notes']
      now = Time.now

      if properties['notes'][id]
        note = properties['notes'][id]
      else
        note = {
          'user_id'    => user_id,
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

  def parent
    (parent_id ? Device.find(parent_id) : nil)
  end

  def children
    Device.where({
      :parent_id => id
    }).to_a
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

      # automatic collection cannot clear a fault, reserved, or available state
        if MANUAL_STATUS.include?(self.status_was)
          if self.collected_at_changed?
            self.status = self.status_was
          end
        end
      end
    end

    def _confine_maintenance_status
      if self.maintenance_status_changed?
        if not VALID_MAINT_STATUS.include?(self.maintenance_status)
          errors.add(:maintenance_status, "Maintenance Status must be one of #{VALID_MAINT_STATUS.join(', ')}")
        end
      end
    end

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end

    def _compact
      self.properties = self.properties.compact
    end

  class<<self
    include App::Helpers

  # urlsearch
  #   perform a query formatted as a URL partial path component
    def urlsearch(query)
      self.where(urlquerypath_to_mongoquery(query))
    end

  # list
  #   list distinct values for a field
    def list(field, query=nil)
      field = case field
      when 'id' then '_' + field
      when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$") then field
      else "properties.#{field}"
      end

      super(field, query)
    end

  # summarize
  #   this method provides arbitrary-depth aggregate rollups of a MongoDB
  #   collection, using the MongoDB Aggregation Framework (mongodb 2.1+)
  #
  #   group_by:   the top-level field to group by
  #   properties: additional fields to drill down into
  #   query:      a query Hash to filter the collection by
  #               (defaults to a summary of the whole collection)
  #
    def summarize(group_by, properties=[], query=nil, options={})
      rv = _get_aggregate_children([group_by]+[*properties].reverse)
    end

    def _get_aggregate_children(properties, parents=[])
      rv = []
      parent = (parents.last || {})

      query = _aggregate_field(properties.first, parents)

      if query
        rv += collection.aggregate(query).to_a.collect{|i|
          i['field'] = properties.first
          children = _get_aggregate_children(properties[1..-1], parents+[i])
          i['children'] = children unless children.empty?
          i
        }
      end

      rv
    end

    def _aggregate_field(field, parents)
      pipeline = nil
      parent = (parents.last || {})

      if field
        basefield = field.split('.').last
        field = _get_field_name(field)
        parent_match = []

        parents.each do |p|
          parent_match << {_get_field_name(p['field']) => p['_id']}
        end

        projection = {
          field => 1
        }

      # add all parent fields to the projection
        unless parent_match.empty?
          parent_match.each do |p|
            projection[p.to_a.first.first] = 1
          end
        end

        pipeline = []
        pipeline << {
          :$project => projection
        }

      # add all parent field values to the match
        unless parent_match.empty?
          pipeline << {
            :$match => {
              :$and => parent_match
            }
          }
        end

        if _is_field_array?(field)
          pipeline << {
            :$unwind => "$#{field}"
          }
        end

        pipeline << {
          :$group => {
            :_id => "$#{field}",
            :count => {
              :$sum => 1
            }
          }
        }

        puts "QUERY #{pipeline}"
      end

      pipeline
    end

    def _get_field_name(field)
      return "properties.#{field}" unless TOP_LEVEL_FIELDS.include?(field)
      field
    end

    def _is_field_array?(field)
      unless TOP_LEVEL_FIELDS.include?(field)
        return ((Device.where({field => {:$exists => 1}}).limit(1).first.to_h.get(field).class.name == "Array") rescue false)
      else
        return (Device.keys[field].type.name == "Array")
      end

      false
    end
  end
end

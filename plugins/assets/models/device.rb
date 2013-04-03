require 'model'
require 'assets/models/node_default'
require 'assets/lib/helpers'

class Device < App::Model::Base
  include App::Model::Taggable

  set_collection_name "devices"

  VALID_STATUS = ['online', 'fault', 'allocatable', 'reserved', 'provisioning', 'installing']
  MANUAL_STATUS = ['fault', 'allocatable', 'reserved']
  NO_AUTOCLEAR_STATUS = ['provisioning', 'installing']


  before_validation :_compact
  before_validation :_mangle_id
  before_validation :_confine_status
  before_validation :_apply_defaults

  timestamps!

  key :name,               String
  key :parent_id,          String
  key :properties,         Hash
  key :tags,               Array
  key :aliases,            Array
  key :collected_at,       Time
  key :status,             String

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

    def _id_pattern_valid?
      errors.add(:id, "Device ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
    end

    def _compact
      self.properties = self.properties.compact
    end

    def _apply_defaults
      device = self.to_h
      merges = []
      except = ['id', 'name']

      NodeDefault.matches(device, except).each do |m|
        device = m.deep_merge(device, {:merge_hash_arrays => true})
      end

      self.from_h(device, false)
      self
    end

  class<<self
    include App::Helpers

  # urlsearch
  # perform a query formatted as a URL partial path component
    def urlsearch(query)
      self.where(urlquerypath_to_mongoquery(query))
    end

  # list
  # list distinct values for a field
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
      fields = ([group_by]+[*properties]).compact.collect{|field|
        case field
        when 'id' then '_' + field
        when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$") then field
        else "properties.#{field}"
        end
      }

      puts query.inspect
      results = (query.nil? ? self.fields(fields).all() : self.where(query).fields(fields)).to_a.collect{|i|
        i.to_h
      }

      results.count_distinct(fields)
    end
  end
end

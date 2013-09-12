require 'model'
require 'assets/models/node_default'
require 'assets/lib/helpers'
require 'automation/models/job'

class Device < App::Model::Base
  include App::Model::Taggable

  set_collection_name "devices"

  VALID_STATUS = ['online', 'allocatable', 'reserved', 'installing']
  MANUAL_STATUS = ['reserved']
  NO_AUTOCLEAR_STATUS = ['provisioning', 'installing']


  before_validation :_compact
  before_validation :_mangle_id
  before_validation :_confine_status
  before_validation :_apply_defaults
  before_validation :_resolve_references

  timestamps!

  key :name,               String
  key :parent_id,          String
  key :properties,         Hash
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

  def defaults
    NodeDefault.defaults_for(self)
  end

  def get(field, default=nil)
    field = case field
    when 'id' then '_' + field
    when Regexp.new("^(#{App::Helpers::TOP_LEVEL_FIELDS.join('|')})$") then field
    else "properties.#{field}"
    end

    return self.to_h.get(field, default)
  end


  def push(key, value, coerce=:auto)
    current_value = self.properties.get(key)
    new_value = value.convert_to(coerce)

  # creation
    if current_value.nil?
      self.properties.set(key, [new_value])

  # append to existing array
    elsif current_value.is_a?(Array)
    # dont append duplicates
      if current_value.select{|i| i.to_s == new_value.to_s }.empty?
        self.properties.set(key, current_value+[new_value])
      end

  # convert scalar -> vector
    else
      self.properties.set(key, ([current_value]+[new_value]))
    end

    self
  end

  def pop(key)
    current_value = self.properties.get(key)\

    if current_value.nil?
      return nil

    elsif current_value.is_a?(Array)
      rv = current_value.pop()

      if current_value.empty?
        self.properties.unset(key)
      else
        self.properties.set(key, current_value)
      end

    else
      rv = current_value
      self.properties.unset(key)
    end

    return rv
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

      # automatic collection cannot clear a reserved state
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
      except = ['id', 'name', 'updated_at', 'created_at']

    # get all defaults that apply to this node
      NodeDefault.defaults_for(self).each do |m|
      # remove fields that cannot/should not be set by a rule
        apply = m.apply.reject{|k,v|
          except.include?(k.to_s)
        }

      # prefix non-top-level keys with properties
        apply = Hash[apply.select{|k,v|
          App::Helpers::TOP_LEVEL_FIELDS.include?(k)
        }].merge({
          'properties' => Hash[apply.reject{|k,v|
            App::Helpers::TOP_LEVEL_FIELDS.include?(k)
          }]
        })

      # autotype the properties being applied
        apply.each_recurse! do |k,v,p|
          if v.is_a?(Array)
            v.collect{|i| (i.autotype() rescue i) }
          else
            v.autotype()
          end
        end

      # force determines whether the applied default overrides the new object
      # being save or can be overridden by it
        if m.force === true
          device = device.deep_merge(apply)
        else
          device = apply.deep_merge(device)
        end
      end

      self.from_h(device, false)
      self
    end

    def _resolve_references
      properties = self.to_h.get('properties').clone

      properties.each_recurse do |k,v,p|
        if v.is_a?(String)
        # resolve expressions
        #
        # expression syntax examples:
        #   {{ field_name }}
        #   {{ field_name:^regular.*expression[0-9]? }}
        #
          properties.set(p, v.gsub(/\{\{\s*(\w+)(?:\:(.*?))?\s*\}\}/){
            x = properties.get($1)
            x = (x.match(Regexp.new($2)).captures.first rescue nil) unless $2.to_s.empty?
            x
          })

          nil
        end
      end

      self.from_h({
        'properties' => properties
      }, false)

      self
    end

  class<<self
    include App::Helpers

  # urlsearch
  # perform a query formatted as a URL partial path component
    def urlsearch(urlquery)
      self.where(Device.to_mongo(urlquery))
    end

    def to_mongo(urlquery)
      return urlquerypath_to_mongoquery(urlquery)
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

      results = (query.nil? ? self.fields(fields) : self.where(query).fields(fields)).collect{|i|
        i.to_h!
      }

      results.count_distinct(fields)
    end
  end
end


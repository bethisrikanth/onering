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
  validate :_id_pattern_valid?

  timestamps!

  key :name,               String
  key :properties,         Hash
  key :user_properties,    Hash
  key :tags,               Array
  key :aliases,            Array
  key :collected_at,       Time
  key :status,             String
  key :maintenance_status, String

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
      query = urlquerypath_to_mongoquery(query) if query
      field = case field
      when 'id' then '_' + field
      when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$") then field
      else "properties.#{field}"
      end

      self.collection.distinct(field, query).compact.sort
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
      unless TOP_LEVEL_FIELDS.include?(group_by)
        group_by = "properties.#{group_by}"
      end

      group_root = group_by.split('.').last.to_sym

      rv = (options[:root] || {})

      q = {
        '$match' => query
      } if query


      c = []
      c << q if query

      c << {
        '$project' => {
          :_id => "$#{group_by}"
        }
      }

      c << {
        '$group' => {
          :_id => "$_id",
          :count => {'$sum' => 1}
        }
      }

    # do initial query on grouping field
      collection.aggregate(c).collect{|i|
        rv[i['_id']] = {
          :id => i['_id'],
          :count => i['count'].to_i
        }
      }

    # ------------------------------------------
    # run subqueries for providing field rollups
      unless properties.empty?
        field = properties.pop


        if field
          field_root = field.gsub('.', '_')

          c = []
          c << q if query

        # project the document down to the group and rollup field
          c << {
            '$project' => {
              :_id => 0,
              group_root => "$#{group_by}",
              :children => "$properties.#{field}"
            }
          }

          #c << {'$unwind' => {'$cond' => [{'$eq' => ['$type', 4]}, "$#{field_root}", "$#{field_root}"]}}


        # group by both group and rollup field, counting the documents in
        # these groups
          c << {
            '$group' => {
              :_id => {
                group_root => "$#{group_root}",
                :children => "$children"
              },
              :count => {'$sum' => 1}
            }
          }

        # group by the group field, breaking the rollup field into a set
        # of value-count pairs
          c << {
            '$group' => {
              :_id => "$_id.#{group_root}",
              :count => {'$sum' => '$count'},
              :children => {
                '$addToSet' => {
                  :_id => {'$ifNull' => ["$_id.children", nil]},
                  :count => '$count'
                }
              }
            }
          }

          collection.aggregate(c).collect{|i|
          # add the current filter to the $match query
            qq = (query.clone rescue {'$and' => []})
            qq['$and'] = [] unless qq['$and']
            qq['$and'] << {group_by => i['_id']}

          # recurse into summarize to next rollup properties
            irv = summarize(field, properties.clone, qq, {
              :root => rv[i['_id']][:children]
            })

            qq['$and'].pop

          # set return value
            rv[i['_id']][:children] = irv
          }
        end
      end

    # return only the top-level hash values
      rv = rv.collect{|k,v| v }
      rv = rv.sort{|a,b| (a[:id] || '') <=> (b[:id] || '') } rescue rv
      rv
    end
  end
end

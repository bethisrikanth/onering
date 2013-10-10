require 'model'
require 'assets/models/node_default'
require 'assets/lib/helpers'
require 'automation/models/job'


class Asset < App::Model::Elasticsearch
  VALID_STATUS = %w{online allocatable installing}
  NO_AUTOCLEAR_STATUS = %w{installing}

  index_options do
    {
      :replication => :async
    }
  end

  field :aliases,                 :string,   :array => true
  field :collected_at,            :date
  field :created_at,              :date,     :default => Time.now
  field :maintenance_status,      :string
  field :name,                    :string
  field :parent_id,               :string
  field :properties,              :object,   :default => {}, :typedefs => App::Config.get("database.options.typedefs.asset.properties")
  field :status,                  :string
  field :tags,                    :string,   :array => true
  field :updated_at,              :date,     :default => Time.now

  field_prefix                    :properties

  settings do
    {
      :index => {
        :analysis => {
          :filter => {
            :remove_expression_tokens => {
              :type        => :pattern_replace,
              :pattern     => '[\:\[\]\*]+',
              :replacement => ''
            }
          },
          :analyzer => {
            :lcwhitespace => {
              :type        => :custom,
              :tokenizer   => :whitespace,
              :filter      => [:lowercase, :remove_expression_tokens]
            }
          }
        }
      }
    }
  end

  mappings do
    {
      :date_detection    => false,
      :index_analyzer    => :whitespace,
      :search_analyzer   => :lcwhitespace,
      :dynamic_templates => [{
        :date_detector => {
          :match    => "*_at",
          :mapping  => {
            :fields => {
              "{name}" => {
                :type   => :date,
                :index  => :analyzed,
                :format => %w{
                  date_hour_minute_second_millis
                  date_time
                  date_time_no_millis
                  yyyy-MM-dd HH:mm:ss ZZZZ
                }
              }
            }
          }
        }
      },{
        :store_generic => {
          :match   => "*",
          :mapping => {
            :store           => "yes",
            :index_analyzer  => :whitespace,
            :search_analyzer => :lcwhitespace
          }
        }
      }]
    }
  end

  #before_save                   :_ensure_id
  before_save                   :_compact
  before_save                   :_confine_status
  before_save                   :_apply_defaults
  #before_save                   :_resolve_references
  #before_save                   :_update_collected_at


  def parent()
    (self.parent_id ? Asset.find(self.parent_id) : nil)
  end

  def children()
    Asset.urlquery("str:parent_id/#{self.id}")
  end

  def defaults
    NodeDefault.defaults_for(self)
  end

  def add_note(body, user_id)
    body = Liquid::Template.parse(body).render({
      :asset => self.to_hash().stringify_keys()
    }) rescue nil
    return false if user_id.nil?
    return false if body.nil?

    notes = self.properties.rget(:notes, [])
    notes << {
      :created_at => Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'), #this is a damned cop-out...
      :user_id    => user_id,
      :body       => body
    }

    self.properties.rset(:notes, notes)
    return true
  end

private
  def _compact()
    unless self.properties.nil?
      self.properties = self.properties.compact
    end
  end

  def _ensure_id()
    if self.id.nil?
      begin
        require 'securerandom'
        self.id = SecureRandom.hex(12)
      rescue LoadError
        self.id = Array.new(24){rand(16).to_s(16)}.join
      end
    end
  end

  def _confine_status()
    if not VALID_STATUS.include?(self.status)
      errors.add(:status, "Status must be one of #{VALID_STATUS.join(', ')}")
      self.status = nil
    end
  end

  def _apply_defaults
    device = self.to_hash()
    merges = []
    except = %w{
      id
      name
      updated_at
      created_at
    }

  # get all defaults that apply to this node
    NodeDefault.defaults_for(self).each do |m|
    # remove fields that cannot/should not be set by a rule
      apply = m.apply.reject{|k,v|
        except.include?(k.to_s)
      }

    # prefix non-top-level keys with field_prefix
      apply = Hash[apply.select{|k,v|
        App::Helpers::TOP_LEVEL_FIELDS.include?(k)
      }].merge({
        Asset.field_prefix() => Hash[apply.reject{|k,v|
          App::Helpers::TOP_LEVEL_FIELDS.include?(k)
        }]
      })

    # autotype the properties being applied
      apply = apply.each_recurse do |k,v,p|
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

    self.from_h(device, false, false)
    self
  end

  def _resolve_references
    unless self.properties.nil?
      properties = self.properties.clone

      self.properties.each_recurse do |k,v,p|
        if v.is_a?(String)
        # resolve expressions
        #
        # expression syntax examples:
        #   {{ field_name }}
        #   {{ field_name:^regular.*expression[0-9]? }}  // optional regex capture
        #
          properties.rset(p, v.gsub(/\{\{\s*(\w+)(?:\:(.*?))?\s*\}\}/){
            x = properties.rget($1)
            x = (x.match(Regexp.new($2)).captures.first rescue nil) unless $2.to_s.empty?
            x
          })

        end

        nil
      end


      self.from_h({
        :properties => properties
      }, false)
    end

    self
  end
end
















# class Asset < App::Model::Elasticsearch
#   include App::Model::Taggable

#   #set_collection_name "devices"

#   VALID_STATUS = ['online', 'allocatable', 'reserved', 'installing']
#   MANUAL_STATUS = ['reserved']
#   NO_AUTOCLEAR_STATUS = ['provisioning', 'installing']


#   before_validation :_compact
#   before_validation :_mangle_id
#   before_validation :_confine_status
#   before_validation :_apply_defaults
#   before_validation :_resolve_references

#   property :id,                 :type =>'string'
#   property :parent_id,          :type =>'string'
#   property :name,               :type =>'string'
#   property :status,             :type =>'string'
#   property :maintenance_status, :type => 'string'
#   property :created_at,         :type => 'date', :default => Time.now
#   property :updated_at,         :type => 'date', :default => Time.now
#   property :collected_at,       :type => 'date'
#   property :tags,               :default => []
#   property :aliases,            :default => []
#   property :properties,         :default => {}


#   def add_note(body, user_id)
#     id = Time.now.to_i.to_s

#     if properties
#       properties['notes'] = {} unless properties['notes']
#       now = Time.now

#       if properties['notes'][id]
#         note = properties['notes'][id]
#       else
#         note = {
#           'user_id'    => user_id,
#           'created_at' => now
#         }
#       end

#       note['body'] = body
#       note['updated_at'] = now

#       properties['notes'][id] = note
#       return true
#     end

#     false
#   end

#   def parent
#     (parent_id ? Asset.find(parent_id) : nil)
#   end

#   def children
#     Asset.search({
#       :parent_id => id
#     }).to_a
#   end

#   def defaults
#     NodeDefault.defaults_for(self)
#   end

#   private
#     def _mangle_id
#       id = id.strip.downcase if id
#     end

#     def _confine_status
#       if self.status_changed?
#         if not VALID_STATUS.include?(self.status)
#           errors.add(:status, "Status must be one of #{VALID_STATUS.join(', ')}")
#         end

#       # automatic collection cannot clear a reserved state
#         if MANUAL_STATUS.include?(self.status_was)
#           if self.collected_at_changed?
#             self.status = self.status_was
#           end
#         end
#       end
#     end

#     def _id_pattern_valid?
#       errors.add(:id, "Asset ID must be at least 6 hexadecimal characters, is: #{id}") if not id =~ /[0-9a-f]{6,}/
#     end

#     def _compact
#       self.properties = self.properties.compact
#     end



#   class<<self
#     include App::Helpers

#   # urlsearch
#   # perform a query formatted as a URL partial path component
#     def urlsearch(urlquery)
#       self.search(Asset.to_mongo(urlquery))
#     end

#     def to_mongo(urlquery)
#       return urlquerypath_to_mongoquery(urlquery)
#     end

#   # list
#   # list distinct values for a field
#     def list(field, query=nil)
#       field = case field
#       when 'id' then '_' + field
#       when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$") then field
#       else "properties.#{field}"
#       end

#       super(field, query)
#     end

#   # summarize
#   #   this method provides arbitrary-depth aggregate rollups of a MongoDB
#   #   collection, using the MongoDB Aggregation Framework (mongodb 2.1+)
#   #
#   #   group_by:   the top-level field to group by
#   #   properties: additional fields to drill down into
#   #   query:      a query Hash to filter the collection by
#   #               (defaults to a summary of the whole collection)
#   #
#     def summarize(group_by, properties=[], query=nil, options={})
#       fields = ([group_by]+[*properties]).compact.collect{|field|
#         case field
#         when 'id' then '_' + field
#         when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$") then field
#         else "properties.#{field}"
#         end
#       }

#       results = (query.nil? ? self.fields(fields) : self.search(query).fields(fields)).collect{|i|
#         i.to_h!
#       }

#       results.count_distinct(fields)
#     end
#   end
# end

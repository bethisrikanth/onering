require 'model'
require 'assets/models/node_default'
require 'assets/lib/helpers'


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
  field :name,                    :string,   :skip_mapping => true  # skip mapping so the dynamic template will handle this field
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
          :char_filter => {
            :remove_expression_tokens => {
              :type        => :pattern_replace,
              :pattern     => '[\:\[\]\*]+',
              :replacement => ''
            }
          },
          :analyzer => {
            :default => {
              :type        => :custom,
              :tokenizer   => :whitespace,
              :filter      => [:lowercase],
              :char_filter => [:remove_expression_tokens]
            }
          }
        }
      }
    }
  end

  mappings do
    {
      :date_detection    => false,
      :dynamic_templates => [{
        :date_detector => {
          :match         => "_at$",
          :match_pattern => :regex,
          :mapping  => {
            :fields => {
              '{name}' => {
                :type   => :date,
                :store  => false,
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
        :unanalyzable => {
          :match   => '*',
          :match_mapping_type => :boolean,
          :mapping => {
            :fields => {
              '{name}' => {
                :store => false,
                :index => :not_analyzed
              }
            }
          }
        }
      },{
        :fields_string => {
          :match   => '*',
          :match_mapping_type => :string,
          :mapping => {
            :type => :multi_field,
            :fields => {
              '{name}' => {
                :store => false,
                :type   => '{dynamic_type}',
                :index => :not_analyzed
              },
              :_analyzed => {
                :store  => false,
                :type   => '{dynamic_type}',
                :index  => :analyzed
              }
            }
          }
        }
      },{
        :fields_default => {
          :match => '.*',
          :match_mapping_type => 'integer|long|float|double',
          :match_pattern => :regex,
          :mapping => {
            :store    => :false,
            :index    => :not_analyzed
          }
        }
      }]
    }
  end

  #before_save                   :_ensure_id
  before_save                   :_compact
  before_save                   :_confine_status
  before_save                   :_apply_defaults
  before_save                   :_resolve_references
  #before_save                   :_print_hash


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
      :created_at => Time.now,
      :user_id    => user_id,
      :body       => body
    }

    self.properties.rset(:notes, notes)
    return true
  end

private
  def _compact()
    unless self.properties.nil?
      self.properties = self.properties.compact()
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

  def _apply_defaults()
    device = self.to_hash()
    except = %w{
      id
      name
      updated_at
      created_at
      collected_at
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
      apply = apply.each_recurse do |k,v,p,dhm|
        if v.is_a?(Array)
          dhm.set(p, v.collect{|i| (i.autotype() rescue i) })
        else
          dhm.set(p, v.autotype())
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

    self.from_hash(device)
    self
  end

  def _resolve_references()
    unless self.properties.nil?
      self.properties = self.properties.each_recurse do |k,v,p,dhm|
        if v.is_a?(String)
        # resolve expressions
        #
        # expression syntax examples:
        #   {{ field_name }}
        #   {{ field_name:^regular.*expression[0-9]? }}  // optional regex capture
        #
          dhm.set(p, v.gsub(/\{\{\s*(\w+)(?:\:(.*?))?\s*\}\}/){
            x = self.properties.rget($1)
            x = (x.match(Regexp.new($2)).captures.first rescue nil) unless $2.to_s.empty?
            x
          })
        end
      end
    end

    self
  end

  def _print_hash()
    pp self.to_hash().reject{|k,v|
      [:properties].include?(k.to_sym)
    }
  end
end

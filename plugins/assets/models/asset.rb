# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'model'
require 'assets/models/node_default'
require 'assets/lib/helpers'


class Asset < App::Model::Elasticsearch
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
  #before_save                   :_compact
  before_save                   :_confine_status
  before_save                   :_apply_defaults
  before_save                   :_resolve_references
  before_save                   :_ensure_uniqueness
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

  def self.states(immutable=false)
    rv = App::Config.get('assets.status.states',{})

    if immutable
      rv = rv.select{|k,v|
        v.get(:immutable, false)
      }
    end

    rv.keys.map(&:to_s)
  end

private
  def _compact()
    unless self.properties.nil?
      self.properties = self.properties.compact()
    end
  end

  def _confine_status()
  # validate that this is a valid status
    if not Asset.states().include?(self.status)
      errors.add(:status, "Status must be one of #{Asset.states().join(', ')}")
      self.status = self.status_was
    end
  end

  def _apply_defaults()
    top_level_fields = (Asset.fields.keys.map(&:to_s) - [Asset.field_prefix])
    device = self.to_hash()
    except = %w{
      id
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
        top_level_fields.include?(k)
      }].merge({
        Asset.field_prefix() => Hash[apply.reject{|k,v|
          top_level_fields.include?(k)
        }]
      })

    # autotype the properties being applied
      apply = apply.each_recurse do |k,v,p,dhm|
        if v.is_a?(Array)
          dhm.set(p, v.collect{|i| i.autotype() })
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
          dhm.set(p, v.gsub(/\{\{\s*([\w\.]+)(?:\:(.*?))?\s*\}\}/){
            x = self.properties.rget($1)
            x = (x.match(Regexp.new($2)).captures.first rescue nil) unless $2.to_s.empty?
            x
          })
        end
      end
    end

    self
  end


  def _ensure_uniqueness()
    App::Config.get('database.options.unique.asset', []).each do |field_name|
      if not self.get(field_name).nil?
      # find all assets with a field value equal to our own
        results = Asset.search({
          :query => {
            :match_phrase => {
              field_name => self.get(field_name)
            }
          }
        })

      # if the list of IDs in the results (less our own) is not empty, then someone else is already using this value. throw an error (yeah, it's that bad)
        if not (dup_ids = results.collect{|i| i.id }.compact.sort - [self.id]).empty?
          raise Tensor::NonUniqueValueError.new("Cannot save asset #{self.id}: The #{self.get(field_name)} is not a unique value for field #{field_name}. Value is shared with asset #{dup_ids.join(', ')}")
        end
      end
    end

    return true
  end


  def _print_hash()
    pp self.to_hash().reject{|k,v|
      [:properties].include?(k.to_sym)
    }
  end
end
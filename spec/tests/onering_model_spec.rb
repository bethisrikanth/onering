require 'spec_helper'
require 'elasticsearch'
require 'patches'
require 'tensor'
require 'config'
require 'model'

class TestOneringModel < App::Model::Elasticsearch
  field :name,       :string
  field :status,     :string
  field :enabled,    :boolean, :default => false
  field :properties, :object,  :default => {}

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
end

describe App::Model::Elasticsearch do
  before(:all) do
    @es = Elasticsearch::Client.new({
      :hosts              => ['localhost:9200'],
      :reload_connections => true
    })

    Tensor::ConnectionPool.connect()
  end

  describe "URLQuery testing" do
    before(:all) do
      TestOneringModel.sync_schema()

      Dir[File.join(File.dirname(__FILE__), 'fixtures', 'tensor', '*.json')].each do |fixture|
        fixture = MultiJson.load(File.read(fixture))
        TestOneringModel.create(fixture)
      end
    end

    after(:all) do
      TestOneringModel.connection.indices.delete({
        :index => TestOneringModel.get_real_index()
      })
    end

    describe "boolean searches" do
      it ": implicit" do
        results = TestOneringModel.urlquery("monitor/true")
        results.should_not be_empty
        results.collect{|i| i.properties['tier'] }.uniq.should == ['prod']
      end

      it ": explicit" do
        results = TestOneringModel.urlquery("bool:monitor/true")
        results.should_not be_empty
        results.collect{|i| i.properties['tier'] }.uniq.should == ['prod']
      end

      it ": implicit (negated)" do
        results = TestOneringModel.urlquery("monitor/not:true")
        results.should_not be_empty
        results.collect{|i| i.properties['tier'] }.uniq.should == ['dev']
      end

      it ": explicit (negated)" do
        results = TestOneringModel.urlquery("bool:monitor/not:true")
        results.should_not be_empty
        results.collect{|i| i.properties['tier'] }.uniq.should == ['dev']
      end
    end

    describe "default string searches" do
      it "- name search (word-character only prefix)" do
        results = TestOneringModel.urlquery("name/db")
        results.should_not be_empty
        results.collect{|i| i.name.split('-').first }.uniq.should == ['db']
        results.collect{|i| i.properties['role'] }.uniq.should == ['db']
      end

      it "- name search (word-character with dash prefix)" do
        results = TestOneringModel.urlquery("name/db-")
        results.should_not be_empty
        results.collect{|i| i.name.split(/\d+/).first }.uniq.should == ['db-']
      end

      it "- name search (word-character with dash and numbers prefix)" do
        results = TestOneringModel.urlquery("name/db-001")
        results.should_not be_empty
        results.collect{|i| i.name.split('.').first }.uniq.should == ['db-001']
      end

      # it "- name search (word-character substring)" do
      #   results = TestOneringModel.urlquery("name/contains:lga1")
      #   results.should_not be_empty
      #   results.collect{|i| i.name.split('.')[2] }.uniq.should == ['lga1']
      #   results.collect{|i| i.properties['site'] }.uniq.should == ['db']
      # end

      # it "- name search (word-character with dot substring)" do
      #   results = TestOneringModel.urlquery("name/contains:prod.lga1")
      #   results.should_not be_empty
      #   results.collect{|i| i.name.split('.')[1] }.uniq.should == ['prod']
      #   results.collect{|i| i.properties['tier'] }.uniq.should == ['prod']
      #   results.collect{|i| i.name.split('.')[2] }.uniq.should == ['lga1']
      #   results.collect{|i| i.properties['site'] }.uniq.should == ['lga1']
      # end

      it "- name search (regex)" do
        results = TestOneringModel.urlquery("name/matches:.*lga1.*")
        results.should_not be_empty
        results.collect{|i| i.name.split('.')[2] }.uniq.should == ['lga1']
        results.collect{|i| i.properties['site'] }.uniq.should == ['lga1']
      end
    end


    describe "field listing" do
      it "- list top-level field" do
        results = TestOneringModel.list("site")
        results.should_not be_empty
        results.sort.should == ['lga1', 'dal1', 'lax1'].sort
      end
    end
  end
end



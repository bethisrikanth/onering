require 'spec_helper'
require 'elasticsearch'
require 'patches'
require 'tensor'

class TestModel < Tensor::Model
  field :name,       :string
  field :status,     :string
  field :enabled,    :boolean, :default => false
  field :properties, :object,  :default => {}
end

describe Tensor::Model do
  before(:all) do
    @es = Elasticsearch::Client.new({
      :hosts              => ['localhost:9200'],
      :reload_connections => true
    })

    Tensor::ConnectionPool.connect()
  end

  it "should be able to connect to the testing Elasticsearch cluster" do
    @es.cluster.health.should                be_kind_of(Hash)
    @es.cluster.health['status'].should_not  == 'red'
  end


  it "should correctly derive index_name" do
    TestModel.index_name.should == "test_models"
  end

  it "should correctly derive document_type" do
    TestModel.document_type.should == "test_model"
  end

  describe TestModel do
    before(:each) do
      TestModel.sync_schema()
    end

    after(:each) do
      TestModel.connection.indices.delete({
        :index => TestModel.get_real_index()
      })
    end


    it "should be able to sync the schema" do
      mapping = TestModel.all_mappings()
      mapping.should                                                                be_kind_of(Hash)
      mapping[TestModel.document_type()].should                                     be_kind_of(Hash)
      mapping[TestModel.document_type()]['properties']['name']['type'].should       == 'string'
      mapping[TestModel.document_type()]['properties']['enabled']['type'].should    == 'boolean'
      mapping[TestModel.document_type()]['properties']['properties']['type'].should == 'object'
    end

    it "create document and verify state pre-save" do
      new_test = TestModel.new({
        :name => "Test Document 1"
      })

      new_test.name.should       == "Test Document 1"
      new_test.enabled.should    be_false
      new_test.properties.should be_kind_of(Hash)
      new_test.properties.should be_empty
    end

    it "create document and verify state post-save" do
      new_test = TestModel.new({
        :name    => "Test Document 2",
        :enabled => true
      })

      new_test.save({
        :reload => true
      })
 
      new_test.id.should_not  be_nil
      new_test.name.should    == "Test Document 2"
      new_test.enabled.should be_true
    end
  end


  describe "Query testing" do
    before(:all) do
      TestModel.sync_schema()

      Dir[File.join(File.dirname(__FILE__), 'fixtures', 'tensor', '*.json')].each do |fixture|
        fixture = MultiJson.load(File.read(fixture))
        TestModel.create(fixture)
      end
    end

    after(:all) do
      TestModel.connection.indices.delete({
        :index => TestModel.get_real_index()
      })
    end


    it ".search()" do
      results = TestModel.search({
        :filter => {
          :term => { 
            :status => "online"
          }
        }
      })

      results.should_not be_empty
    end
  end
end



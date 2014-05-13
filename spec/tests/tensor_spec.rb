require 'spec_helper'
require 'elasticsearch'
require 'patches'
require 'tensor'

class TestTensorModel < Tensor::Model
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
    TestTensorModel.index_name.should == "test_tensor_models"
  end

  it "should correctly derive document_type" do
    TestTensorModel.document_type.should == "test_tensor_model"
  end

  describe TestTensorModel do
    before(:each) do
      TestTensorModel.sync_schema()
    end

    after(:each) do
      TestTensorModel.connection.indices.delete({
        :index => TestTensorModel.get_real_index()
      })
    end


    it "should be able to sync the schema" do
      mapping = TestTensorModel.all_mappings()
      mapping.should                                                                be_kind_of(Hash)
      mapping[TestTensorModel.document_type()].should                                     be_kind_of(Hash)
      mapping[TestTensorModel.document_type()]['properties']['name']['type'].should       == 'string'
      mapping[TestTensorModel.document_type()]['properties']['enabled']['type'].should    == 'boolean'
      mapping[TestTensorModel.document_type()]['properties']['properties']['type'].should == 'object'
    end

    it "create document and verify state pre-save" do
      new_test = TestTensorModel.new({
        :name => "Test Document 1"
      })

      new_test.name.should       == "Test Document 1"
      new_test.enabled.should    be_false
      new_test.properties.should be_kind_of(Hash)
      new_test.properties.should be_empty
    end

    it "create document and verify state post-save" do
      new_test = TestTensorModel.new({
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
      TestTensorModel.sync_schema()

      Dir[File.join(File.dirname(__FILE__), 'fixtures', 'tensor', '*.json')].each do |fixture|
        fixture = MultiJson.load(File.read(fixture))
        TestTensorModel.create(fixture)
      end
    end

    after(:all) do
      TestTensorModel.connection.indices.delete({
        :index => TestTensorModel.get_real_index()
      })
    end


    it ".search()" do
      results = TestTensorModel.search({
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



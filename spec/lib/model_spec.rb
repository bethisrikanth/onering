require "spec_helper"
require "lib/test_model"

describe "App::Model"  do
  describe "Utils" do
    describe "to_h" do
      before :each do
        @m = TestModel.new
      end
      it "new object should only to_h it's id" do
        @m.to_h.should == {"id" => @m.id}
      end
      it "the property _type should not be serializble, but all others should" do
        @m["_type"] = 5
        @m["x"] = 7
        @m.to_h.should == {"id" => @m.id, "x" => 7}
      end
    end
    describe "to_json" do
      before :each do
        @m = TestModel.new
      end
      it "should make a json string" do
        @m["x"] = 7
        @m.to_json.should == {"id" => @m.id, "x" => 7}.to_json
      end
    end
  end
end


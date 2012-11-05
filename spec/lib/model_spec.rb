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
      it "the property _type should not be serializble" do
        @m["_type"] = 5
        @m["x"] = 7
        @m.to_h.should == {"id" => @m.id, "x" => 7}
      end
    end
  end
end


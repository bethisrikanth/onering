require "spec_helper"

describe "device"  do
  before :each do
    @device = Device.new
  end
  it "should have a name" do
    @device.name = "xxx"
    @device.name.should == "xxx"
  end

  describe "validations" do
    it "empty id should not be valid " do
      @device.id = ""
      @device.should_not be_valid
    end
    it "short id should not be valid " do
      @device.id = "123"
      @device.should_not be_valid
    end
    it "6 hex id should be valid " do
      @device.id = "123abc"
      @device.should be_valid
    end
  end
end
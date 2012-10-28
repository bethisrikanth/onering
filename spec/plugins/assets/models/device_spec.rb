require File.join(File.dirname(__FILE__), '../../../../plugins/assets/models', 'device.rb')

describe "device"  do
  before :each do
    @device = Device.new
  end
  it "should have a name" do
    @device.name = "xxx"
    @device.name.should == "xxx"
  end
end
require 'spec_helper'

def valid_rack_attributes
  {
    name: "rack name",
    index: 0
  }
end

describe PhysicalRack do
  before :each do
    @rack = PhysicalRack.new(valid_rack_attributes)
  end
  describe 'to_param' do
    it "should map simple names correctly" do
      @rack.name = 'xxx'
      @rack.to_param.should == 'xxx'
    end
    it "should map names with . in them correctly" do
      @rack.name = 'xxx.yyy'
      @rack.to_param.should == 'xxx-yyy'
    end
  end

  describe 'add_missing_hosts' do
    it "Should not add any hosts on an empty rack" do
      @rack.physical_hosts.size.should == 0
      @rack.add_missing_hosts
      @rack.physical_hosts.size.should == 0
    end
    it "Should fill the gap for host index == 4" do
      @rack.save!
      @rack.physical_hosts << PhysicalHost.new(u: 4, name: "4", n: 0)
      @rack.save!
      @rack.add_missing_hosts
      @rack.physical_hosts.size.should == 4
    end
  end
end
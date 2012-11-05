module App
  module Database
    class Seed
      require 'mongo'
      require 'mongo_mapper'

      def self.clean
        count = Device.count
        puts "Going to delete #{count} Devices"
        res = Device.remove
        puts "Success? #{res}"
      end

      def self.seed
        Device.create({:id => '1111111', :properties => {:site => 'ladc1'}})
        Device.create({:id => '1111112', :properties => {:site => 'ladc1'}})
        Device.create({:id => '1111113', :properties => {:site => 'ladc1'}})
        Device.create({:id => '1111114', :properties => {:site => 'chidc1'}})
        Device.create({:id => '1111115', :properties => {:site => 'chidc1'}})
        Device.create({:id => '1111116', :properties => {:site => 'nydc1'}})
        puts "Database has #{Device.count} Devices"
      end
    end
  end
end
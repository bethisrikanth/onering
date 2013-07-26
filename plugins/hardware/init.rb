require 'controller'
require 'assets/models/device'
require 'hardware/models/rack'

module App
  class Base < Controller
    namespace '/api/hardware' do
      %w{
        /list/racks/:site/?
        /list/racks/:site/:rack/?
      }.each do |r|
        get r do#ne

        end
      end
    end
  end
end

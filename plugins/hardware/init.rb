require 'controller'
require 'hardware/models/rack'

module App
  class Base < Controller
    namespace '/api/hardware' do
      %w{
        /list/racks/:site/?
        /list/racks/:site/:rack/?
      }.each do |r|
        get r do#ne
          if params[:rack]
            rv = Hardware::Rack.where({
              '$and' => [{
                :site => params[:site]
              },{
                :name => params[:rack]
              }]
            }).first.to_h
          else
            rv = Hardware::Rack.where({
              :site => params[:site]
            }).collect{|i| i.to_h }.sort{|a,b| a['name'] <=> b['name'] }
          end

          output(rv)
        end
      end
    end
  end
end

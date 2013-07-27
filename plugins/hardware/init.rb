require 'controller'
require 'hardware/models/rack'

module App
  class Base < Controller
    namespace '/api/hardware' do
      namespace '/rack' do
        get '/:site/?' do
          output(Hardware::Rack.where({
            :site => params[:site]
          }).collect{|i| i.to_h }.sort{|a,b| a['name'] <=> b['name'] })
        end


        get '/:site/:rack/?' do
          output(Hardware::Rack.where({
            '$and' => [{
              :site => params[:site]
            },{
              :name => params[:rack]
            }]
          }).first.to_h)
        end


        post '/:site/:rack/?' do
          rack = Hardware::Rack.where({
            '$and' => [{
              :site => params[:site]
            },{
              :name => params[:rack]
            }]
          }).first

          rack = Hardware::Rack.new unless rack


          json = MultiJson.load(request.env['rack.input'].read)
          json.delete('units')
          rack.from_json(json, false, true).safe_save

          200
        end

        delete '/:site/:rack/?' do
          rack = Hardware::Rack.where({
            '$and' => [{
              :site => params[:site]
            },{
              :name => params[:rack]
            }]
          }).first

          return 404 unless rack

          rack.destroy()

          200
        end
      end
    end
  end
end

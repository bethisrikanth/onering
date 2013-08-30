require 'controller'
require 'hardware/models/rack'
require 'assets/models/asset'
require 'organization/models/contact'

module App
  class Base < Controller
    namespace '/api/hardware' do
      namespace '/sites' do
        get '/?' do
          sites = Config.get('hardware.sites', Asset.list(:site))

          output(sites.collect{|site|
            {
              :id => site,
              :contact => (Contact.where({
                'properties.site' => site
              }).to_a.first.to_hash rescue nil),
              :summary => {

              }
            }.compact
          })
        end
      end

      namespace '/rack' do
        get '/:site/?' do
          output(Hardware::Rack.where({
            :site => params[:site]
          }).collect{|i| i.to_hash }.sort{|a,b| a['name'] <=> b['name'] })
        end


        get '/:site/:rack/?' do
          output(Hardware::Rack.where({
            '$and' => [{
              :site => params[:site]
            },{
              :name => params[:rack]
            }]
          }).first.to_hash)
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
          json.set('site', params[:site])
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

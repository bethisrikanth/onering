require 'controller'
require 'mongo_mapper'
require 'assets/models/device'

module App
  class Base < Controller
    configure do
      MongoMapper.setup({
        'production' => {
          'uri' => 'mongodb://localhost'
        }
      }, 'production')

      MongoMapper.database = 'onering'
    end

  # device by id
    get '/devices/:id' do
      device = Device.find(params[:id])
      return 404 if not device
      device.to_json
    end

    %w{
      /devices/?
      /devices/:id
    }.each do |route|
      any route, %w{post put} do
        rv = []
        json = JSON.parse(request.body.read)
        json = [json] if json.is_a?(Hash)

        json.each do |o|
          id = (params[:id] || o['id'])

          device = Device.find_or_create(id)
          device.from_json(o)
          device.safe_save

          rv << device
        end

        rv.to_json
      end
    end

  # path and tag query
    %w{
      /devices/tagged/*/?
      /devices/in/:site/:rack/?
      /devices/in/:site/:rack/*/?
      /devices/in/:site/:rack/u:unit/?
      /devices/in/:site/:rack/U:unit/?
      /devices/in/:site/?
    }.each do |route|
      get route do
        site = params[:site]
        rack = params[:rack]
        unit = params[:unit]
        tags = (params[:splat].first || '').split('/')
        q = {}

        q['attributes.site'] = site if site
        q['attributes.rack'] = rack if rack
        q['attributes.unit'] = unit if unit

      # if a single tag is specified, search for it as a scalar
      # otherwise include all tags as required
        q['tags'] = case tags.length
          when 1 then tags.first
          else        {'$all' => tags}
        end if not tags.empty?

      # run the query
        rv = Device.where(q)

      # collapse single-element arrays (if specified)
        rv = rv.first if params[:collapse] and rv.length == 1

        return 404 if not rv
        rv.to_json
      end
    end
  end
end

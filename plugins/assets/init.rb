require 'controller'
require 'mongo_mapper'
require 'assets/lib/helpers'
require 'assets/models/device'

module App
  class Base < Controller
    include Helpers

    namespace '/api/devices' do
    # device by id
      get '/:id' do
        device = Device.find(params[:id])
        return 404 if not device
        device.to_json
      end

      %w{
        /?
        /:id
      }.each do |route|
        post route do
          rv = []
          json = JSON.parse(request.env["rack.input"].read)
          json = [json] if json.is_a?(Hash)

          json.each do |o|
            id = (params[:id] || o['id'])

            device = Device.find_or_create(id)
            device.from_json(o).safe_save

            rv << device
          end

          rv.to_json
        end
      end


    # set device user properties
      get '/:id/set/*' do
        device = Device.find(params[:id])
        return 404 if not device

        if not params[:splat].empty?
          prop = device.properties
          pairs = params[:splat].first.split('/')

        # set each property
          pairs.evens.zip(pairs.odds).each do |pair|
            prop[pair.first] = pair.last
          end

        # set and save
          device.properties = prop
          device.safe_save
        end

        device.to_json
      end


    # tagging
    # these are GETs because this should be a trivial user action
      get '/:id/tag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Device.find(params[:id])
        tags.each{|t| device.tags.push_uniq(t) }
        device.safe_save
        device.to_json
      end


      get '/:id/untag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Device.find(params[:id])
        tags.each{|t| device.tags.delete(t) }
        device.safe_save
        device.to_json
      end


      # /devices/find
      # search for devices by fields
      %w{
        /find/?
        /find/*
      }.each do |r|
        get r do
          q = (!params[:splat] || params[:splat].empty? ? (params[:q] || {}) : params[:splat].first)
          Device.where(urlquerypath_to_mongoquery(q)).to_json
        end
      end


    # show devices that haven't been updated
      %w{
        /list/stale/?
        /list/stale/:age
      }.each do |r|
        get r do
          Device.where({
            'updated_at' => {
              '$lte' => (params[:age] || 4).to_i.hours.ago
            },
            'tags' => 'auto'
          }).to_json
        end
      end

    # /devices/list
    # list field values
      %w{
        /list/:field/?
        /list/:field/where/*
      }.each do |r|
        get r do
          q = urlquerypath_to_mongoquery(params[:splat].empty? ? nil : params[:splat].first)
          field = case params[:field]
          when 'id' then '_' + params[:field]
          when /name|tags/ then params[:field]
          else "properties.#{params[:field]}"
          end

          Device.sort(field.to_sym.asc)
          Device.collection.distinct(field, q).compact.to_json
        end
      end


    # /devices/summary
      %w{
        /summary/by-:field/?
        /summary/by-:field/*/?
      }.each do |r|
        get r do
          q = urlquerypath_to_mongoquery(params[:where])
          rv = Device.summarize(params[:field], (params[:splat].first.split('/').reverse rescue []), q)
          rv.to_json
        end
      end
    end
  end
end

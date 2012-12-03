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
        /stats
        /:id/stats
      }.each do |route|
        get route do
          stat = DeviceStat.find(params[:id])
          return 404 if not stat
          stat.to_json
        end

        post route do
          json = JSON.parse(request.env['rack.input'].read)
          json = [json] if json.is_a?(Hash)

          json.each do |o|
            id = (params[:id] || o['id'])
            stat = DeviceStat.find_or_create(id)
            stat.from_json(o['stats'], false).safe_save
          end

          200
        end
      end

      %w{
        /?
        /:id
      }.each do |route|
        post route do
          json = JSON.parse(request.env['rack.input'].read)
          json = [json] if json.is_a?(Hash)

          json.each do |o|
            id = (params[:id] || o['id'])

            device = Device.find_or_create(id)

          # update the collected_at timestamp if this is an inventory run
            device['collected_at'] = Time.now if o.delete('inventory')

            device.from_json(o).safe_save
          end

          200
        end
      end

      %w{
        /:id/notes/?
        /:id/notes/:note_id/?
      }.each do |route|
        post route do
          device = Device.find(params[:id])
          return 404 if not device
          device.add_note(request.env['rack.input'].read)
          device.safe_save

          200
        end

        delete route do
          device = Device.find(params[:id])
          return 404 if not device

          if device.properties and device.properties['notes']
            device.properties['notes'].delete(params[:note_id])
            device.properties.delete('notes') if device.properties['notes'].empty?
            device.safe_save
          end

          200
        end
      end


    # set devices properties
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

    # get device property
      get '/:id/get/*' do
        content_type 'text/plain'
        device = Device.find(params[:id])
        return 404 if not device
        rv = []
        params[:splat].first.split('/').each do |key|
          rv << (device.properties[key] || ' ').to_s
        end

        return rv.join("\n")
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

        post r do
          q = (!params[:splat] || params[:splat].empty? ? (params[:q] || {}) : params[:splat].first)
          q = urlquerypath_to_mongoquery(q)
          set = params[:set].split(';').collect{|i| i=i.split(':'); ["properties.#{i.first}", i.last] }

          Device.set(q, Hash[set])
          #Device.where(q).to_json
        end
      end


    # show devices that haven't been updated
      %w{
        /list/stale/?
        /list/stale/:age
      }.each do |r|
        get r do
          Device.where({
            'collected_at' => {
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

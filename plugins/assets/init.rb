require 'controller'
require 'mongo_mapper'
require 'assets/lib/helpers'
require 'assets/models/device'
require 'assets/models/node_default'
require 'automation/models/job'

module App
  class Base < Controller
    include Helpers

    namespace '/api/devices' do
      namespace '/defaults' do
        get '/sync' do
          output(Automation::Job.find_by_name('assets-sync').request())
        end

        get '/list' do
          output(NodeDefault.all.to_a.collect{|i|
            i = i.to_h
            i['apply'] = i['apply'].coalesce(nil,nil,'.')
            i
          })
        end

        get '/:id' do
          default = NodeDefault.find(params[:id])
          return 404 unless default
          output(default.to_h)
        end

        delete '/:id' do
          default = NodeDefault.find(params[:id])
          return 404 unless default
          NodeDefault.destroy(params[:id])
          200
        end

        %w{
          /?
          /:id
        }.each do |r|
          post r do
            default = (params[:id] ? NodeDefault.find(params[:id]) : NodeDefault.new())
            return 404 unless default

            json = MultiJson.load(request.env['rack.input'].read)
            json = [json] if json.is_a?(Hash)

            json.each do |o|
              if o['apply']
                apply = o['apply'].clone
                o['apply'] = {}
                apply.each{|k,v| o['apply'].set(k.split(/[\_\.]/), v) }
              end

              default.from_json(o, false, true).safe_save
            end

            200
          end
        end
      end

    # device by id
      get '/:id' do
        device = Device.find(params[:id])
        return 404 if not device
        d = device.to_h

        d[:children] = device.children.collect{|i|
          filter_hash(i.to_h, :properties)
        } if params[:children]

        output(filter_hash(d, :properties))
      end

      delete '/:id' do
        Device.destroy(params[:id])
        200
      end


    # device pane configurations
      get '/:id/panes' do
        output([{
          :id        => 'system',
          :template  => 'node-pane-system'
        },{
          :id        => 'apps',
          :title     => 'Applications',
          :template  => 'node-pane-apps'
        },{
          :id        => 'config',
          :title     => 'Configuration',
          :template  => 'node-pane-config'
        }])
      end


      get '/:id/parent' do
        allowed_to? :get_asset, params[:id]
        device = Device.find(params[:id])
        return 404 unless device and device.parent_id and device.parent
        output(filter_hash(device.parent.to_h, :properties))
      end

      get '/:id/children' do
        allowed_to? :get_asset, params[:id]
        device = Device.find(params[:id])
        return 404 unless device
        output(device.children.collect{|i|
          allowed_to?(:get_asset, i.id) rescue next
          filter_hash(i.to_h, :properties)
        })
      end


      get '/:id/defaults' do
        allowed_to? :get_asset, params[:id]
        device = Device.find(params[:id])
        return 404 unless device

        output(device.defaults.collect{|i|
          i.to_h
        })
      end


    # child management operations
      get '/:id/children/:action/?*/?' do
        allowed_to? :update_asset, params[:id]
        device = Device.find(params[:id])
        action = params[:action].to_s.downcase.to_sym
        child_ids = params[:splat].first.split('/')
        return 404 unless device


      # set operation works on all children
        if action == :set or action == :unset
          children = Device.where({
            :parent_id => params[:id]
          }).to_a

        # an empty existing set means we're just going to take the incoming set as gospel
          if children.empty? and action == :set
            children = Device.find(child_ids)
          end
        else
      # add/remove can operate exclusively on named child IDs
          children = Device.find(child_ids)
        end

        children.each do |child|
          allowed_to?(:update_asset, child.id) rescue next

          case action
          when :add    then child.parent_id = params[:id]
          when :remove, :unset then child.parent_id = nil
          when :set    then
          # if the current child is in the set, set its parent
            if child_ids.include?(child.id)
              child.parent_id = params[:id]
            else
              child.parent_id = nil
            end
          end

          child.safe_save
        end

        output(device)
      end

      %w{
        /?
        /:id
      }.each do |route|
        post route do
          job = Automation::Job.find_by_name('assets-update')
          return 503 unless job

          data = request.env['rack.input'].read

          if params[:id]
            id = params[:id]
          else
            json = MultiJson.load(data)
            id = json['id']
          end

          if params[:direct].to_bool === true
            json = MultiJson.load(data) unless json
            json['collected_at'] = Time.now if json['inventory'] === true
            device = Device.find(id)
            return 404 unless device
            device.from_h(json)
            device.safe_save
            device.reload
            output(device)
          else
            output(job.request({
              :data       => data,
              :parameters => {
                :nodes => [id]
              }
            }))
          end
        end
      end

      %w{
        /:id/notes/?
        /:id/notes/:note_id/?
      }.each do |route|
        post route do
          device = Device.find(params[:id])
          return 404 if not device
          device.add_note(request.env['rack.input'].read, @user.id)
          device.safe_save

          200
        end

        delete route do
          device = Device.find(params[:id])
          return 404 if not device

          if device.properties and device.properties['notes']
            if device.properties['notes'][params[:note_id]]
              allowed_to? :remove_asset_note, device.properties['notes'][params[:note_id]]

              device.properties['notes'].delete(params[:note_id])
              device.properties.delete('notes') if device.properties['notes'].empty?
              device.safe_save
            end
          end

          200
        end
      end


    # set devices properties
      %w{
        set
        unset
      }.each do |action|
        get "/:id/#{action}/:key/:value" do
          device = Device.find(params[:id])
          return 404 if not device

          if action == 'set'
            device.properties.set(params[:key], params[:value].convert_to(params[:coerce] || :auto))
          else
            device.properties.delete(params[:key])
          end

          device.safe_save
          output(device)
        end
      end

    # get device property
      get '/:id/get/*' do
        content_type 'text/plain'
        device = Device.find(params[:id])
        return 404 if not device
        rv = []
        params[:splat].first.split('/').each do |key|
          rv << (device.properties.get(key) || ' ').to_s
        end

        rv.join("\n")
      end


    # tagging
    # these are GETs because this should be a trivial user action
      get '/:id/tag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Device.find(params[:id])
        tags.each{|t| device.tags.push_uniq(t) }
        device.safe_save
        output(device)
      end


      get '/:id/untag/*' do
        tags = params[:splat].first.split(/\W/)
        device = Device.find(params[:id])
        tags.each{|t| device.tags.delete(t) }
        device.safe_save
        output(device)
      end


    # status
    # set the status of a device
      get '/:id/status/:status' do
        device = Device.find(params[:id])
        return 404 if not device
        if params[:status] == 'unknown'
          if (Device::VALID_STATUS - Device::MANUAL_STATUS - Device::NO_AUTOCLEAR_STATUS).include?(device.status)
            device.unset(:status)
            device.reload
          end
        else
          device.status = params[:status]
          device.safe_save
        end

        output(device)
      end

    # maintenance_status
    # set the maintenance_status of a device
      get '/:id/maintenance/:status' do
        device = Device.find(params[:id])
        return 404 if not device
        if params[:status] == 'healthy'
          device.unset(:maintenance_status)
          device.reload
        else
          device.maintenance_status = params[:status]
          device.safe_save
        end

        output device.to_h
      end


      # /devices/find
      # search for devices by fields
      %w{
        /find/?
        /find/*
      }.each do |r|
        get r do
          qsq = (params[:q] || params[:query] || '')
          q = (!params[:splat] || params[:splat].empty? ? qsq : params[:splat].first.split('/').join('/')+(qsq ? '/'+qsq : ''))
          rv = Device.urlsearch(q).limit(params[:limit] || 1000).to_a

          output(filter_hash(rv, :properties))
        end
      end


    # show devices that haven't been updated
      %w{
        /list/stale/?
        /list/stale/:age
      }.each do |r|
        get r do
          output(Device.list('id', {
            'collected_at' => {
              '$lte' => (params[:age] || 4).to_i.hours.ago
            }
          }))
        end
      end

    # /devices/list
    # list field values
      %w{
        /list/:field/?
        /list/:field/where/*
      }.each do |r|
        get r do
          q = (params[:splat].empty? ? (params[:where].to_s.empty? ? params[:q] : params[:where]) : params[:splat].first)
          output Device.list(params[:field], urlquerypath_to_mongoquery(q))
        end
      end


    # /devices/summary
      %w{
        /summary/by-:field/?
        /summary/by-:field/*/?
      }.each do |r|
        get r do
          q = urlquerypath_to_mongoquery(params[:where] || params[:q])
          rv = Device.summarize(params[:field], (params[:splat].first.split('/').reverse rescue []), q)
          output rv
        end
      end
    end
  end
end

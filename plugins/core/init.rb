require 'controller'
require 'core/models/pam_user'
require 'core/models/ldap_user'

module App
  class Base < Controller
    before do
      if Config.get('global.force_ssl')
        port = (request.port == 80 ? '' : ":#{request.port}")
        redirect "https://#{request.host}#{port}", 301
      end

      unless Config.get('global.authentication.disable') then
        @user = nil
        auth = Rack::Auth::Basic::Request.new(request.env)

        unless auth.provided? then
          response['WWW-Authenticate'] = "Basic realm=\"#{Config.get('global.authentication.realm') || 'HTTP Authentication'}\""
          throw :halt, 401
        end

        throw :halt, 400 unless auth.basic?

      # this will become the correct class using MM Single-collection inheritance
        user = User.find(auth.username)

        if user
          if user.authenticate!({
            :username => auth.username,
            :password => auth.credentials[1]
          })
            @user = user

          else
            throw :halt, 401
          end
        else
          throw :halt, 401
        end

        # if user found
        #   unless user.authenticated?(o)
        #     throw :halt, 403
        #   end

        #   unless user.authorized?(request.request_method, request.path_info)
        #     throw :halt, 403
        #   end

        #   user is okay to continue
        # else
        #   throw :halt, 401
        # end
      end
    end

    get '/' do
      index = File.join(settings.public_folder, 'index.html')
      File.read(index) if File.exists?(index)
    end

  # anything in the /api namespace will be JSON (for now, other types pending)
    namespace '/api' do
      before do
        content_type 'application/json'
      end

      get '/?' do
        output({
          :status => 'ok',
          :local_root => ENV['PROJECT_ROOT'],
          :environment => settings.environment,
          :backend_server_port => request.env['SERVER_PORT'],
          :backend_server_string => request.env['SERVER_SOFTWARE'],
          :remote_addr => request.env['REMOTE_ADDR'],
          :request_url => request.url,
          :current_user => (@user ? @user.id : nil)
        })
      end


    # user management
      namespace '/users' do
      # get user list
        get '/list' do
          return 403 unless @user.capability(:list_users)
          users = User.all
          output(users)
        end

      # get user
        get '/:id' do
          return 403 unless @user.capability(:get_user, params[:id])

          user = User.find(params[:id])
          return 404 unless user
          output(user)
        end

      # update user
        post '/:id' do
          return 403 unless @user.capability(:update_user, params[:id])

          json = JSON.load(request.env['rack.input'].read)

          if json
            id = (params[:id] || o['id'])

          # remove this field, it gets handled in another endpoint
            json.delete('_type')

            user = User.find_or_create(id)
            user.from_json(json).safe_save

            200
          else
            raise "Invalid JSON submitted"
          end
        end

      # update user type
        get '/:id/type/:type' do
          return 403 unless @user.capability(:update_user_type, id)

          user = User.find(params[:id])
          return 404 unless user
          user.type = params[:type]
          user.safe_save
          output(user)
        end
      end
    end

  end
end

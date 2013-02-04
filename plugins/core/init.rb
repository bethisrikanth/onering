require 'controller'
require 'core/models/user'

module App
  class Base < Controller
    before do
      unless Config.get('global.authentication.disable') then
        auth = Rack::Auth::Basic::Request.new(request.env)

        unless auth.provided? then
          response['WWW-Authenticate'] = "Basic realm=\"#{Config.get('global.authentication.realm') || 'HTTP Authentication'}\""
          throw :halt, 401
        end

        throw :halt, 400 unless auth.basic?

        # find user by auth.username, auth.credentials[1]

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
        {
          :status => 'ok',
          :local_root => ENV['PROJECT_ROOT'],
          :environment => settings.environment,
          :backend_server_port => request.env['SERVER_PORT'],
          :backend_server_string => request.env['SERVER_SOFTWARE'],
          :remote_addr => request.env['REMOTE_ADDR']
        }.to_json
      end
    end

  end
end

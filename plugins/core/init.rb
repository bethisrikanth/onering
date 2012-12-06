require 'controller'

module App
  class Base < Controller
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

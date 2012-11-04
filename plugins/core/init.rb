require 'controller'

module App
  class Base < Controller
    get '/' do
      {
        :status => 'ok',
        :local_root => PROJECT_ROOT,
        :environment => settings.environment
      }.to_json
    end
    get '/config/web.json' do
      {}.to_json # TODO: Added this just so the html won't error. Garry, what did you mean by that $.getJSON('/config/web.json' ?
    end
  end
end

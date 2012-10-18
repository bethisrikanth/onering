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

    get '/doc/routes' do
      rv = App::Base.routes['GET'].collect{|i| i.first }
      rv.to_json
    end 

    get '/test/config/*' do
      Config.get(params[:splat].first, 'fallback').to_json
    end
  end
end

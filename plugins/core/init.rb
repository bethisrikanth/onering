require 'controller'

module App
  class Base < Controller
    set :haml, :format => :html5

    get '/', :provides => 'html' do
      pass unless request.accept.include? "text/html"
      haml :index
    end

    get '/', :provides => 'json' do 
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

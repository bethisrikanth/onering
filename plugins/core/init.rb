require 'controller'

module App
  class Base < Controller
    get '/' do 
      {
        :status => 'ok'
      }.to_json
    end

    get '/doc/routes' do
      rv = App::Base.routes['GET'].collect{|i| i.first }
      rv.to_json
    end 
  end
end

require 'controller'
require 'organization/models/contact'

module App
  class Base < Controller
    namespace '/api/org' do
      namespace '/contacts' do
        get '/find/?' do
          Contact.all.collect{|i| i.to_h }.to_json
        end

        get '/find/:field/:query' do
          output(Contact.urlquery([params[:field], params[:query]].join('/')).collect{|i|
            i.to_hash()
          })
        end

        get '/:id' do
          output(Contact.find(params[:id]))
        end
      end
    end
  end
end

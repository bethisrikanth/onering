require 'controller'
require 'organization/models/contact'

module App
  class Base < Controller
    include Helpers

    namespace '/api/org' do
      namespace '/contacts' do
        get '/:id' do
          Contact.find(params[:id]).to_json rescue 404
        end

        get '/find/:field/:query' do
          Contact.where({
            params[:field] => Regexp.new(params[:query], Regexp::IGNORECASE)
          }).collect{|i| i.to_h }.to_json rescue 404
        end
      end
    end
  end
end

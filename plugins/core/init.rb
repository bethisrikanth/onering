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
  end
end

require 'controller'
require 'assets/models/device'

module App
  class Base < Controller
    namespace '/api/rundeck' do
      get '/nodes/?*' do
        nodes = Device.urlsearch("bool:orchestrate/not:false/"+params[:splat].first)
        return 404 if nodes.empty?

        content_type 'text/x-yaml'

        return YAML.dump(nodes.collect{|node|
          {
            'nodename'  => node.get('rundeck.name', node.id),
            'hostname'  => (node.get(Config.get('automation.rundeck.fields.hostname') || 'fqdn') || node.name || node.id),
            'username'  => node.get('rundeck.user', Config.get('automation.rundeck.user', 'rundeck')),
            'tags'      => node.tags,
            'osVersion' => node.get('version'),
            'osName'    => node.get('distro'),
            'osArch'    => node.get('arch')
          }.compact
        })
      end
    end
  end
end

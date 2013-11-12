# LISTEN I'M NOT GONNA FIGHT YOU ON THIS BUT SOMETIMES DECISIONS GET MADE AND WE GOTTA LIVE WITH THEM
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil

module Automation
  module Tasks
    module Chef
      class DeleteClient < Task
        def self.perform(id, node={}, *args)
          require 'ridley'

          config = App::Config.get!('chef.client')
          fail("Malformed Chef client configuration; expected Hash but got #{config.class.name}") unless config.is_a?(Hash)

          chef = Ridley.new({
            :server_url   => config.get(:server_url),
            :client_name  => config.get(:username),
            :client_key   => config.get(:keyfile),
            :ssl => {
              :verify => false
            }
          })

          client = nil
          candidate_clients = []
          candidate_clients << node.get('chef.name')
          candidate_clients << node.get('name')
          candidate_clients << id

          candidate_clients.compact.each do |candidate|
            if (client = chef.client.find(candidate))
              break
            end
          end

          fail("Could not find a Chef client for node #{id}") if client.nil?

          info("Deleting Chef client #{client.name}")
          chef.client.delete(client)
        end
      end
    end
  end
end

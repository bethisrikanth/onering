require 'rpam'
require 'auth/models/user'

class PamUser < User
  index_name    "users"
  document_type "pam_user"

  inherit_fields!

  def authenticate!(options={})
    if super
      service = App::Config.get('global.authentication.methods.pam.service', 'onering')
      options[:username] = id

      begin
      # using rpam-ruby19 (https://github.com/canweriotnow/rpam-ruby19)
        if Rpam.respond_to?(:auth)
          return Rpam.auth(options[:username], options[:password], {
            :service => service
          })
        else
      # rpam legacy (http://rpam.rubyforge.org/)
      #
      # NOTE: this version does not work on Ruby 1.8 and does not support
      #       specifying the PAM service name (hardcoded to 'rpam')
      #       > e.g. /etc/pam.d/rpam
      #
          include Rpam
          return authpam(options[:username], options[:password])
        end

        return false
      rescue Exception => e
        STDERR.puts "PAM Error: #{e.class.name}: #{e.message}"
      end
    end
  end
end

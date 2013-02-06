require 'pam'
require 'core/models/user'

class PamUser < User
  CONVERSATION = Proc.new do |messages, data|
    rv = []
    data = {} unless data

    messages.each do |message|
      case message.msg_style
      when PAM::PAM_PROMPT_ECHO_ON
        rv << PAM::Response.new(data[:username], 0)

      when PAM::PAM_PROMPT_ECHO_OFF
        rv << PAM::Response.new(data[:password], 0)

      else
        rv << PAM::Response.new(nil, 0)

      end
    end

    rv
  end

  def authenticate!(options={})
    if super
      service = App::Config.get('global.authentication.pam.service')

      begin
        puts "PAM authentication for service #{service}, user #{options[:username]}"

        PAM.start(service, options[:username], CONVERSATION, options) do |pam|
          begin
            pam.authenticate(0)
          rescue PAM::PAM_USER_UNKNOWN
            STDERR.puts "Unknown user #{options[:username]}"
            return false

          rescue PAM::PAM_AUTH_ERR
            STDERR.puts "Authentication failed for user #{options[:username]}"
            return false

          rescue PAM::PAMError => e
            STDERR.puts "PAM Authenticate Error: #{e.message}"
            return false

          end

          begin
            pam.acct_mgmt(0)
            pam.open_session do
              return true
            end
          rescue PAM::PAMError => e
            STDERR.puts "PAM Error: #{e.message}"
          end
        end

        return false
      rescue Exception => e
        STDERR.puts "PAM Error: #{e.class.name}: #{e.message}"
      end
    end
  end
end
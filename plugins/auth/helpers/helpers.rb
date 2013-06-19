module App
  module Helpers
    def anonymous?(path)
      %w{
        ^/$
        ^/api/?$
        ^/api/users/login/?$
        ^/api/users/machine/?.*$
        ^/api/provision/?.*$
        ^/api/rundeck/nodes/?.*$
        ^/api/ipxe/boot/?.*$
      }.each do |p|
        return true if path =~ Regexp.new(p)
      end

      return false
    end

    def ssl_verified?
      (request.env['HTTP_X_CLIENT_VERIFY'] === 'SUCCESS')
    end

    def ssl_hash(type)
    # looks for ENVVAR X-SSL-(.*)
      (request.env["HTTP_X_SSL_#{type.to_s.upcase}"] ? request.env["HTTP_X_SSL_#{type.to_s.upcase}"].to_s.sub(/^\//,'').split('/').collect{|i| i.split('=') } : nil)
    end
  end
end

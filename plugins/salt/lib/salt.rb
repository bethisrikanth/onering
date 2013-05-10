require 'uri'
require 'net/http'
require 'multi_json'
require 'hashlib'

module Salt
  class API
    attr :uri

    def initialize(uri)
      @uri = (uri.is_a?(URI) ? uri : URI(uri))
    end

    def run(command, arguments=nil, opts={})
      request = Net::HTTP::Post.new("/run")
      request.add_field "Content-Type", "application/json"
      request.body = MultiJson.dump({
        :commands  => [*command],
        :arguments => (arguments.nil? ? nil : [*arguments])
      }.compact.merge(opts))

      http = Net::HTTP.new(@uri.host, @uri.port)
      http.open_timeout = 5
      http.read_timeout = 5

      response = http.request(request)

      [Integer(response.code), (MultiJson.load(response.body) rescue nil)]
    end
  end
end
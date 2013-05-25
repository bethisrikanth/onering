require 'uri'
require 'net/http'
require 'multi_json'
require 'hashlib'

module Salt
  class API
    class ExitLoop < Exception; end

    RESULTS_MAX_WAIT_SECS = 30
    RESULTS_CHECK_INTV_DELAY = 3

    attr :uri

    def initialize(uri)
      @uri = (uri.is_a?(URI) ? uri : URI(uri))
    end

    def run(commands, arguments=nil, opts={})
      request = Net::HTTP::Post.new("/run")
      request.add_field "Content-Type", "application/json"
      request.body = MultiJson.dump({
        :commands  => [*commands],
        :arguments => (arguments.nil? ? nil : [*arguments])
      }.compact.merge(opts))

      http = Net::HTTP.new(@uri.host, @uri.port)
      http.open_timeout = 5
      http.read_timeout = 5

      response = http.request(request)

      [Integer(response.code), (MultiJson.load(response.body) rescue nil)]
    end

    def results(job_id, opts={}, &block)
      request = Net::HTTP::Get.new("/results/#{job_id}")
      rv = []
      started = Time.now.to_i

      catch(:done) do
        loop do
          http = Net::HTTP.new(@uri.host, @uri.port)
          http.open_timeout = 5
          http.read_timeout = 10
          response = http.request(request)

          if Integer(response.code) < 400
            v = MultiJson.load(response.body)

            unless v.empty?
              rv += v
              yield v if block_given?

            end

            throw :done if rv.length >= Integer(opts[:limit]) unless opts[:limit].nil?
            throw :done if (Time.now.to_i - started) >= (opts[:max_wait].to_i || RESULTS_MAX_WAIT_SECS)
          end

          sleep(RESULTS_CHECK_INTV_DELAY)
        end

        return rv
      end

      rv
    end
  end
end
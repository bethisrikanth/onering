module App
  class Controller < Sinatra::Base
    before do
      headers 'Access-Control-Allow-Origin' => '*'
    end

    class<<self
      def any(url, verbs=%w(get post put delete), &block)
        verbs.each do |verb|
          send(verb, url, &block)
        end
      end
    end
  end
end
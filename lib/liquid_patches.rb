require 'liquid'

module App
  module Liquid
    module Filters
      def or(*args)
        args.each{|arg| return arg if arg }
        nil #else
      end

      def and(*args)
        args[1..-1].each{|arg| return nil unless arg }
        args.first
      end
    end
  end
end

Liquid::Template.register_filter(App::Liquid::Filters)
require 'model'
require 'assets/lib/helpers'

class NodeDefault < App::Model::Base
  set_collection_name "node_defaults"

  timestamps!

  key :match, Array
  key :apply, Hash

  def match?(hash)
    unless self.apply.nil? or self.apply.empty?
      [*self.match].each do |query|
        values = hash.get(query['field'])

        [*values].each do |value|
          case query['test']
          when 'regex'
            if value =~ Regexp.new(query['value'], Regexp::IGNORECASE)
              return true
            end

          when 'exists'
            return (!value.nil?)

          else
            if value.to_s.strip.chomp == query['value'].to_s.strip.chomp
              return true
            end
          end
        end
      end
    end

    return false
  end

  class<<self
    include App::Helpers

    def matches(hash, except=[])
      rv = []
      self.all.each do |default|
        apply = default.to_h['apply']
        apply.reject!{|k,v|
          except.include?(k)
        }

        rv << (apply if default.match?(hash) rescue nil)
      end

      rv.compact
    end
  end
end

require 'deep_merge/rails_compat'
require 'hashlib'
require 'net/http'

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def to_bool
    !(self.chomp.strip =~ /^(?:true|on|yes|y|1)$/i).nil?
  end

  def autotype(strip=true)
    test = (strip ? self.to_s.strip.chomp : self)
    return nil if test.empty?

    case test
  # float
    when /^[0-9]+\.[0-9]+$/
      return test.to_f()

  # int
    when /^[0-9]+$/
      return test.to_i()

  # bool
    when /^(?:true|on|yes|y|1|0|n|no|off|false)$/i
      return test.to_bool()

  # nulls
    when /^(?:null|nil|empty)$/i
      return nil
    end

    return self
  end
end

module ActiveSupport
  class HashWithIndifferentAccess < Hash
    def to_yaml(opts = {})
      self.to_hash.to_yaml(opts)
    end
  end
end

class Array
  def odds
    values_at(*each_index.select{|i| i.odd?})
  end

  def evens
    values_at(*each_index.select{|i| i.even?})
  end

  def push_uniq(value)
    self << value unless include?(value)
  end
end
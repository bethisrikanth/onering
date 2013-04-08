require 'deep_merge/rails_compat'
require 'hashlib'
require 'net/http'

class String
  SI_UNITS=%w{b k m g t p e z y}

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

  def convert_to(to=nil)
    case (to.to_sym rescue nil)
    when :auto
      return self.autotype()

    when :bool
      return self.to_bool()

    when :date
      return (Time.parse(self) rescue nil)

    when :epoch
      return (Time.at(Integer(self)) rescue nil)

    when :float
      return (Float(self) rescue nil)

    when :int
      return (Integer(self) rescue nil)

    when :str
      return self

    when :bits
      if self =~ /^([0-9]+)([bkmgtpezy])$/
        return Integer($1) * (1024 ** (SI_UNITS.index($2).to_i))
      else
        return nil
      end

    when :bytes
      if self =~ /^([0-9]+)([BKMGTPEZY])$/
        return Integer($1) * (1024 ** (SI_UNITS.index($2.downcase).to_i))
      else
        return nil
      end

    else
      return self
    end
  end

  def autotype()
    return nil if self.empty?

    case self
  # float
    when /^[0-9]+\.[0-9]+$/
      return self.to_f()

  # int
    when /^[0-9]+$/
      return self.to_i()

  # bool
    when /^(?:true|on|yes|y|1|0|n|no|off|false)$/i
      return self.to_bool()

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
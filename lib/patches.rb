require 'deep_merge/rails_compat'
require 'hashlib'
require 'net/http'
require 'time'

class Object
  def if_else(value, if_true, otherwise=nil)
    return (self == value ? if_true : otherwise)
  end

  def deep_clone()
    Marshal.load(Marshal.dump(self))
  end
end

class TrueClass
  def to_bool
    self
  end
end

class FalseClass
  def to_bool
    self
  end
end

class NilClass
  def to_bool
    false
  end

  def autotype(*args)
    self
  end

  def coerce(*args)
    self
  end
end

class String
  SI_UNITS=%w{b k m g t p e z y}

  def underscore()
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def camelize()
    self.split('_').collect{|i| i.capitalize }.join()
  end

  def nil_empty()
    return nil if self.strip.empty?
    self
  end

  def to_bool
    !(self.chomp.strip =~ /^(?:true|on|yes|y|1)$/i).nil?
  end

  def as_date(format=nil)
    begin
    # no format, autoparse
      return Time.parse(self) if format.nil?

    # format given, use DateTime.strptime
      return DateTime.strptime(self, format)

    rescue ArgumentError
      return nil
    end
  end

  def convert_to(to=nil)
    case (to.to_sym rescue nil)
    when :auto
      return self.autotype()

    when :bool
      return self.to_bool()

    when :date
      begin
        case self
        when 'yesterday'
          return (Time.now - 1.days)

        when 'now'
          return Time.now

        when 'tomorrow'
          return (Time.now + 1.days)

        when /([\-0-9]+)(s|secs?|seconds?)$/i
          return (Time.at(Time.now.to_i - Integer($1) ))

        when /([\-0-9]+)(m|mins?|minutes?)$/
          return (Time.at(Time.now.to_i - (Integer($1) * 60) ))

        when /([\-0-9]+)(h|hrs?|hours?)$/i
          return (Time.at(Time.now.to_i - (Integer($1) * 60 * 60) ))

        when /([\-0-9]+)(d|dys?|days?)$/i
          return (Time.at(Time.now.to_i - (Integer($1) * 60 * 60 * 24) ))

        when /([\-0-9]+)(w|wks?|weeks?)$/i
          return (Time.at(Time.now.to_i - (Integer($1) * 60 * 60 * 24 * 7) ))

        when /([\-0-9]+)(M|mns?|mons?|months?)$/
          return (Time.at(Time.now.to_i - (Integer($1) * 60 * 60 * 24 * 30) ))

        when /([\-0-9]+)(y|yrs?|years?)$/i
          return (Time.at(Time.now.to_i - (Integer($1) * 60 * 60 * 24 * 365) ))

        else
          return Time.parse(self)
        end
      rescue Exception
        return nil
      end

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

  # dates :-(
  #   ruby will readily just parse ANYTHING that contains numbers, so:
  #   strings must be at least 75% numeric to be parsed as a date
    if ((self.gsub(/\D+/,'').length.to_f / self.length.to_f) > 0.75)
      rv = (Time.parse(self) rescue nil)
      return rv unless rv.nil?
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

  def nil_empty()
    return nil if self.empty?
    self
  end

  def to_json
    MultiJson.dump(self)
  end
end

class Hash
  def to_json
    MultiJson.dump(self)
  end
end


class TeeIO
  require 'stringio'
  attr 'tee'

  def initialize(tee, original)
    @tee = tee
    @original = original
  end

  def write(buf)
  # write buffer to both outputs
    @tee << buf
    @original << buf
  end
end

module Kernel
  def capture
    buffer = StringIO.new()
    $stdout = buffer
    $stderr = buffer
    yield
    return buffer.string
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end

  def tee
    buffer = StringIO.new()
    $stdout = TeeIO.new(buffer, $stdout)
    $stderr = TeeIO.new(buffer, $stderr)
    yield
    return buffer.string
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end
end
require 'deep_merge/rails_compat'
require 'net/http'

module Net
  class HTTP
    alias old_initialize initialize

    def initialize(*args)
        old_initialize(*args)
        @read_timeout = 10
    end
  end
end

class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
  end

  def to_bool
    self.chomp.strip =~ /^(true|on|yes|y|1)$/i
  end
end

class Hash
  def diff(other)
    self.keys.inject({}) do |memo, key|
      unless self[key] == other[key]
        if other[key].is_a?(Hash)
          memo[key] = self[key].diff(other[key])
        else
          memo[key] = [self[key], other[key]]
        end
      end
      memo
    end
  end

  def get(path, default=nil)
    root = self

    begin
      path.strip.scan(/[a-z0-9]+(?:\[[^\]]+\])?/).to_a.each do |p|
        x, key, subfield, subvalue = p.split(/([a-z0-9]+)(?:\[([^=]+)(?:=(.+))?\])?/i)
        root = (root[key] rescue nil)
        #puts key, root.inspect

        if subfield and root.is_a?(Array)
          root.each do |r|
            if r.is_a?(Hash) and r[subfield] and ( (subvalue && r[subfield].to_s == subvalue) || true)
              root = r
              break
            end
          end
        end
      end

      return root || default
    rescue NoMethodError
      return default
    end
  end

  def set(path, value)
    path = path.strip.split(/[\/\.]/)
    root = self

    path[0..-2].each do |p|
      root[p] = {} unless root[p].is_a?(Hash)
      root = root[p]
    end

    root[path.last] = value
  end

  def join(inner_delimiter, outer_delimiter=nil)
    outer_delimiter = inner_delimiter unless outer_delimiter
    self.to_a.collect{|i| i.join(inner_delimiter) }.join(outer_delimiter)
  end

  def coalesce(prefix=nil, base=nil)
    base = self unless base
    rv = {}

    if base.is_a?(Hash)
      base.each do |k,v|
        base.coalesce(k,v).each do |kk,vv|
          kk = kk.gsub(/(^_+|_+$)/,'')
          kk = (prefix.to_s+'_'+kk.to_s) if prefix
          rv[kk.to_s] = vv
        end
      end
    else
      rv[prefix.to_s] = base
    end

    rv
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
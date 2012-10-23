class String
  def underscore
    self.gsub(/::/, '/').
    gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
    gsub(/([a-z\d])([A-Z])/,'\1_\2').
    tr("-", "_").
    downcase
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
      path.strip.split(/[\/\.]/).each do |p|
        root = root[p]
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
end

class Array
  def odds
    values_at(*each_index.select{|i| i.odd?})
  end

  def evens
    values_at(*each_index.select{|i| i.even?})
  end
end
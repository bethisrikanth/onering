require 'bson'

module Mongo
  class Cursor
    def to_pure_a
      rv = []

      each{|doc| rv << doc.to_h }

      rv
    end
  end
end

class BSON::OrderedHash
  def to_h
    inject({}) { |acc, element| k,v = element; acc[k] = (if v.class == BSON::OrderedHash then v.to_h else v end); acc }
  end
end
module App
  module Helpers
  # /lib/find/album/containsvalue[+andcontains][:orcontains][+] ? s=field1[,-field2]

  # generates a mongodb query hash from a field-urlquery
  # URL path (e.g.: field1/query1/field2/query2/..)
    def urlquerypath_to_mongoquery(query, regex=true)
      if query
        rv = {}

        pairs = query.split('/')
        pairs = pairs.evens.zip(pairs.odds)

        pairs.each do |p|
          rv['$and'] = [] if not rv['$and']
          fieldExists = (p[0].gsub!(/^\^/,'') == nil)

          # autodetect type for p[1] := v
          v = p[1]
          v = get_rx_from_urlquery(v) if regex and v.is_a?(String)

        # list of places to search for a given value
          case p[0]
          when /^id$/
            rv['$and'] << {'_'+p[0] => (v || {'$exists' => fieldExists})}
          when /name|tags/
            rv['$and'] << {p[0] => (v || {'$exists' => fieldExists})}
          else
            rv['$and'] << {"properties.#{p[0]}" => (v || {'$exists' => fieldExists})}
          end
        end

        return rv
      end

      return nil
    end


    def get_rx_from_urlquery(value)
      rv = []
      
    # logical operators
      op = "([\+])"
      value.gsub!('.', "\\.")
      value.gsub!(Regexp.new("#{op}([^\+]*)"), '\1\2\1')

      value.split(Regexp.new(op)).each do |v|
        if v == '+'
          v = '(?=.*%s.*)' % rv.pop
        else
          v = v.gsub('~', '.*')
          v = "(#{v.gsub(':', '|')})" if v.include?(':')
        end

        rv << v
      end

      return {"$regex" => rv.join}
    end
  end
end
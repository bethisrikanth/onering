module App
  module Helpers
  # TODO: move this into the Device model definition
    TOP_LEVEL_FIELDS = ['id', 'parent_id', 'name', 'tags', 'aliases', 'status']

  # generates a mongodb query hash from a field-urlquery
  # URL path (e.g.: field1/query1/field2/query2/..)
    def urlquerypath_to_mongoquery(query, regex=true, autofield='properties')
      if query
        pairs = query.split('/')
        pairs = pairs.evens.zip(pairs.odds)

        rv = {'$and' => []}

        pairs.each do |p|
          q = {'$or' => []}
          fieldNames = p[0].split(':')

          fieldNames.each do |field|
            fieldExists = (field.gsub!(/^\^/,'') == nil)


            v = p[1].to_s.autotype()
            v = get_rx_from_urlquery(v) if regex and v.is_a?(String)

          # list of places to search for a given value
            case field
            when /^id$/
              q['$or'] << {'_'+field => (v.nil? ? {'$exists' => fieldExists} : v)}
            when Regexp.new("^(#{TOP_LEVEL_FIELDS.join('|')})$")
              q['$or'] << {field => (v.nil? ? {'$exists' => fieldExists} : v)}
            else
              q['$or'] << {"#{autofield}.#{field}" => (v.nil? ? {'$exists' => fieldExists} : v)}
            end
          end

          rv['$and'] << q
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
          negate = (v[0].chr == '!')
          v = v.gsub(/^\!/, '')
          v = v.gsub('~', '.*')
          v = "(#{v.gsub(':', '|')})" if v.include?(':')
          v = '^(?!.*%s.*).*$' % v if negate
        end

        rv << v
      end

      return {"$regex" => rv.join, '$options' => 'i'}
    end
  end
end
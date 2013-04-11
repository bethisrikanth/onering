module App
  module Helpers
    require 'assets/lib/mongo_urlquery_parser'

  # TODO: fix external references to this to stop this madness
    TOP_LEVEL_FIELDS = MongoUrlqueryParser::TOP_LEVEL_FIELDS

    def urlquerypath_to_mongoquery(query)
      if query
        query.gsub!(/(?:^\/|\/$)/, '')
        @@_parser ||= MongoUrlqueryParser.new()
        rv = @@_parser.parse(query).to_mongo_query()
        return rv
      end
    end
  end
end
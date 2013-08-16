require 'net/http'

class GraphiteGraph
  class<<self
    def query(graph)
      uri = _build_uri(graph)
      return [] if uri.nil?

      rv = Net::HTTP.get_response(uri).body
      rv = MultiJson.load(rv)

      return nil unless rv.is_a?(Array)

      data = data(rv)
    end

    def data(results)
      rv = {}
      results.each do |series|
        series['datapoints'].each do |value, time|
          time = (time)
          rv[time] ||= []
          rv[time] << value
        end
      end

      rv = rv.collect{|k,v|
        out = {
          :time   => k,
          :values => []
        }

        v.each_index do |i|
          out[:values] << v[i]
        end

        out
      }

      return [rv, results.collect{|i| {:name => i['target']} }]
    end

  private
    def _build_uri(graph)
      base    = App::Config.get!("dash.backends.#{graph.get(:backend)}.url")
      params  = App::Config.get("dash.backends.#{graph.get(:backend)}.params", {}).merge(graph.get('options.params',{}))
      params  = params.collect{|k,v| k.to_s+'='+v.to_s }.join('&')
      params  = '&'+params unless params.empty?
      targets = []

      series = graph.get(:series,[])
      return nil if series.empty?

      series.each do |s|
        targets << s.get(:name)
      end

      return URI("#{base}/render?format=json#{params}&#{targets.collect{|i| 'target='+i }.join('&')}")
    end
  end
end
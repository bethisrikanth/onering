require 'controller'

module App
  class Base < Controller
    namespace '/api/dashboard' do

      get '/test' do
        output({
          :title  => "Test Chart of Awesome Power",
          :series => [{
            :name  => "entries",
            :color => "red"
          },{
            :name => "others"
          }],
          :colors => {
            "f*" => "green",
            "o*" => "blue",
            :default => "black"
          }
        })
      end

      get '/test/data' do
        rv = {}
        t = Time.now.to_i
        times = 5.times.collect{|i| t+i }

        graphite = [{
          "target" => "entries",
          "datapoints" => [
            [1.0, 0],
            [2.0, 1],
            [3.0, 2],
            [5.0, 3],
            [6.0, 4]
          ]
        },{
          "target" => "others",
          "datapoints" => [
            [16.0, 0],
            [22.0, 1],
            [13.0, 2],
            [15.0, 3],
            [16.0, 4]
          ]
        }]

        graphite.each do |series|
          series['datapoints'].each do |value, time|
            time = (times[time]*1000)
            rv[time] ||= []
            rv[time] << (rand() * value)
          end
        end

        content_type 'text/plain'
        rv.collect{|k,v| "#{k},#{v.join(',')}" }.join("\n")
      end
    end
  end
end

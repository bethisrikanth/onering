require 'httparty'
require 'harbormaster/lib/util'

module Harbormaster
  module Autoscaling
    class Graphite
      include Util

      def self.instance_count(task, consolidated_value=nil)
        config = {
          :check_interval => 300,
          :from           => '-10minutes',
          :to             => 'now',
          :consolidation  => 'average',
          :multiplier     => 1.0,
          :step           => 1,
          :max_missing    => nil
        }.merge(task.scaling.get(:config,{}).symbolize_keys())

      # if we're NOT mocking a cval for testing the multiplier and step functions
        if consolidated_value.nil?
          if config.get(:url).nil?
            Onering::Logger.warn("URL missing from scaling configuration", "Harbormaster::Autoscaling::Graphite")
            return nil
          end

          begin
            response = HTTParty.get(config.get(:url), {
              :timeout => config.get(:timeout, 5),
              :query => {
                :format => :json,
                :from   => config[:from],
                :to     => config[:to]
              }
            })
          rescue SocketError
            Onering::Logger.error("Name or service not known: #{URI(config.get(:url)).host}", "Harbormaster::Autoscaling::Graphite")
            return nil
          end

          if response.code < 300
            if response.parsed_response.is_a?(Array)
              samples_ubound = (-1 * (config.get(:discard_samples, 1).to_i + 1))
              samples_lbound = (-1 * config.get(:samples).to_i) + (samples_ubound + 1)

            # get the Y-values from all datapoints returned
              values = response.parsed_response.collect{|series|
              # bounding limits via 'samples' and 'discard_samples'
              #   in graphite queries, the most recent data returned will include values
              #   that are currently in flux, that is, as new data continues to be sent to
              #   the graphite server, graphite is consolidating that with existing data as
              #   per the consolidation rules that were configured.  this results in a point
              #   that "keeps moving", the values changing to reflect the most recent data
              #
              #   for the purposes of scaling a cluster of tasks, this introduces noise and
              #   complex emergent behavior into the system because there's a time-dependent
              #   instability in the numbers you're working with
              #
              #   for this case, you can choose to discard n metrics from the resultant datapoints
              #   for each series returned.  you can also select how many samples you wish to pull
              #   from the datapoints set, so that is also adjusted accordingly
              #
              #   [1,2,3,4,5,6,7,8,9], samples=5, discard_samples=1 :
              #   results in [1,2,3,4,5,6,7,8,9][-6..-2] => [4,5,6,7,8]
              #
                series['datapoints'][[samples_lbound, (-1*series['datapoints'].length)].max()..samples_ubound].collect{|point|
                  point[0]
                }
              }.flatten()

            # fail if too many values are missing
              if not config.get(:max_missing).nil? and
                 (nils = values.select{|i| i.nil? }.length) > config.get(:max_missing)
              then
                Onering::Logger.warn("Too many missing values from check result (#{nils})", "Harbormaster::Autoscaling::Graphite")
                return nil
              end

            # consolidate the values
              consolidated_value = _consolidate(values, config.get(:consolidation))

            else
              Onering::Logger.warn("Improper format received from scaling check source", "Harbormaster::Autoscaling::Graphite")
              return nil
            end
          else
            Onering::Logger.warn("Received HTTP #{response.code} while performing scaling check", "Harbormaster::Autoscaling::Graphite")
            return nil
          end
        end

      # one way or another we need a cval by now
        if not consolidated_value.nil?
        # apply the multiplier
          consolidated_value = (consolidated_value * config.get(:multiplier,1).to_f)


        # round to nearest step value
          if config.get(:step,1) > 1
            consolidated_value = (consolidated_value / config.get(:step,1).to_i).round() * config.get(:step,1).to_i
          end

        # return that shit
          return consolidated_value.round()
        else
          Onering::Logger.warn("No value set from scaling check", "Harbormaster::Autoscaling::Graphite")
          return nil
        end
      end
    end
  end
end
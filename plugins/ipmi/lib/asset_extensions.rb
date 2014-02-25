# Copyright 2012 Outbrain, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'assets/models/asset'

module Ipmi
  module AssetExtensions
    DEFAULT_IPMI_PING_TIMEOUT=5

    def ipmi_command(command, options={})
      ipmi_ip = self.get(:ipmi_ip)
      unless ipmi_ip
        Onering::Logger.error("Cannot issue IPMI command, field ipmi_ip is empty")
        return false
      end

    # load config
      config = ipmi_get_config(self)

      timeout = config.get('timeout.connect', DEFAULT_IPMI_PING_TIMEOUT)
      unless Net::Ping::ICMP.new(ipmi_ip, nil, timeout).ping?
        Onering::Logger.error("Cannot ping #{ipmi_ip}, timeout was #{timeout} seconds")
        return false
      end

    # check for presence of username
      unless config.get('authentication.username')
        Onering::Logger.error("IPMI username not configured for node #{self.id}")
        return false
      end

    # check for presence of password
      unless config.get('authentication.password')
        Onering::Logger.error("IPMI password not configured for node #{self.id}")
        return false
      end

      ipmi = Rubyipmi.connect(config.get('authentication.username'), config.get('authentication.password'), ipmi_ip)

      begin
        command = command.gsub(/\.is_(.*)/, '.\1?')

        Onering::Logger.debug("Issuing #{command} command to node #{self.id} (#{ipmi_ip}, #{ipmi.fru.manufacturer} #{ipmi.fru.serial})")

        klass = ipmi

        parts = command.split('.')

        parts.each.with_index do |part,i|
          begin
            if i == (parts.length - 1)
              if options[:arguments].nil?
                klass = klass.send(part.to_sym)
              else
                klass = klass.send(part.to_sym, *[*options[:arguments]])
              end
            else
              klass = klass.send(part.to_sym)
            end
          rescue NoMethodError
            Onering::Logger.error("No such command #{command}")
            return false
          end
        end

        return klass

      rescue NoMethodError
        Onering::Logger.error("IPMI command failed, please verify credentials are valid")
      end

      return false
    end

    def ipmi_get_config(node, options={})
      config = App::Config.get('ipmi.default', {})
      mergeroot = App::Config.get('ipmi.options', {})

      mergeroot.each do |property, values|
        values.each do |value, opts|
          case property
          when 'node'
            if node.id == value
              config = config.deep_merge(opts)
            end
          else
            if node.get(property) =~ Regexp.new(value, Regexp::IGNORECASE)
              config = config.deep_merge(opts)
            end
          end
        end
      end

      @_ipmi_config = config.deep_merge(options)
      @_ipmi_config
    end
  end
end

class Asset < App::Model::Elasticsearch
  include Ipmi::AssetExtensions
end
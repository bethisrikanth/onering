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

module Onering
  class PluginLoader
    require 'fileutils'

    def self.eval_ringfile(file, &block)
      if block_given?
        Onering::Logger.debug("Evaluating Ringfile from block", "Onering::PluginLoader")
        content = yield
      else
        Onering::Logger.debug("Loading Ringfile at #{file}", "Onering::PluginLoader")
        content = File.open(file).read()
      end

      if content
        eval(content, binding)
      end
    end

    def self.plugin(name, version)
      if name.nil? or name.empty? or not version.to_s =~ /^\d\.\d\.\d$/
        Onering::Logger.fatal("Plugin must specify a string name and a version in the format x.y.z")
      end

      @_plugins ||= {}

      if @_plugins.has_key(name.to_sym)
        plugin = @_plugins[name.to_sym]

        if plugin[:version].delete('.').to_i > version.delete('.').to_i
          Onering::Logger.fatal("Plugin #{name} is already registered and is newer than #{version} (currently: #{plugin[:version]})")
        else
          Onering::Logger.fatal("Plugin #{name} is already registered")
        end
      else
        @_plugins[name.to_sym] = {
          :version => version
        }

        return true
      end

      return false
    end

    def self.plugins()
      @_plugins || {}
    end

    def self.plugin_root(name=nil)
      File.expand_path(File.join(ENV['PROJECT_ROOT'], 'plugins', name.to_s)).gsub(/\/$/,'')
    end

    def self.temp_root(name=nil)
      File.expand_path(File.join(ENV['PROJECT_ROOT'], 'tmp', name.to_s)).gsub(/\/$/,'')
    end
  end
end


# load the loaders
Dir[File.join(File.dirname(__FILE__), 'loaders', '*.rb')].each do |p|
  p = File.basename(p, '.rb')

  begin
    Onering::Logger.debug("Loading plugin loader #{p}", "Onering")
    require "loaders/#{p}"
  rescue LoadError
    Onering::Logger.warn("Unable to load plugin loader #{p}", "Onering")
    next
  end
end
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

ENV['PROJECT_ROOT'] = File.dirname(File.dirname(File.expand_path(__FILE__)))
$: << File.join(ENV['PROJECT_ROOT'], 'lib')
$: << File.join(ENV['PROJECT_ROOT'], 'plugins')

require 'rubygems'
require 'oj'
require 'onering'

Onering::Logger.setup({
  :destination => 'STDERR',
  :threshold   => (ENV['LOGLEVEL'] || 'INFO').downcase.to_sym
})


require './lib/config'
App::Config.load(ENV['PROJECT_ROOT'])


require 'patches'
require 'metrics'
require 'utils'
require 'model'
require 'controller'
#require 'plugin_loader'
require 'eventmachine'
require 'multi_json'
require 'liquid_patches'
require 'pp'
require 'core/models/configuration'

# initialize model logging
Tensor::Model.logger = Onering::Logger.logger()

# if File.exists?(root_ringfile = File.join(ENV['PROJECT_ROOT'], "Ringfile"))
#   Onering::PluginLoader.eval_ringfile(root_ringfile)
# end

# Dir[File.join(ENV['PROJECT_ROOT'],'plugins', '*', 'Ringfile')].each do |ringfile|
#   Onering::PluginLoader.eval_ringfile(ringfile)
# end

# initialize database settings
App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))

# require plugins
Dir[File.join(ENV['PROJECT_ROOT'],'plugins', '*')].each do |p|
  name = File.basename(p)

  begin
    Onering::Logger.debug("Loading plugin #{name}", "Onering")
    require "#{name}/init"
  rescue LoadError
    next
  end
end

# merge configuration data from the database into the data loaded from files
Onering::Logger.debug("Loading configuration from database", "Onering")
Configuration.sync_remote_with_local()

module App
  class Base < Controller
    def initialize
      App::Metrics.setup()
      App::Metrics.increment("api.process.started")
      super
    end


    configure do
      mime_type :json, 'application/json'

      set :root, ENV['PROJECT_ROOT']
      set :environment, ENV['RACK_ENV'].to_sym if ENV['RACK_ENV']
      set :protection, :except => :json_csrf

      enable  :logging
      #enable  :raise_errors
      disable :raise_errors
      disable :debug
      set     :views, File.join(ENV['PROJECT_ROOT'], 'config', 'templates')

      ::Liquid::Template.file_system = ::Liquid::LocalFileSystem.new(settings.views)
    end

    before do
      Configuration.sync_remote_with_local()
    end

    error do
      content_type 'application/json'

      {
        :error => {
          :type => env['sinatra.error'].class.to_s,
          :message => env['sinatra.error'].message,
          :backtrace => env['sinatra.error'].backtrace,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 400 do
      content_type 'application/json'
      message = (response.body.empty? ? "Invalid or malformed request for resource #{request.path}" : [*response.body].join(','))

      output({
        :error => {
          :type => "Bad Request",
          :message => message,
          :severity  => params[:severity]
        }
      })
    end

    error 401 do
      content_type 'application/json'
      message = (response.body.empty? ? "Invalid credentials for accessing #{request.path}" : [*response.body].join(','))

      {
        :error => {
          :type => "Unauthorized",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 403 do
      content_type 'application/json'
      message = (response.body.empty? ? "User #{@user.id || 'anonymous'} is not authorized to access #{request.path}" : [*response.body].join(','))

      {
        :error => {
          :type => "Forbidden",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end

    error 404 do
      content_type 'application/json'
      message = (response.body.empty? ? "Resource #{request.path} does not exist" : [*response.body].join(','))

      {
        :error => {
          :type => "Not Found",
          :message => message,
          :severity  => params[:severity]
        }
      }.to_json
    end
  end
end

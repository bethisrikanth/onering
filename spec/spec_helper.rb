####################################
## TODO(ran): This section is just a poor copy-paste of config.ru with a slight modification of PROJECT_ROOT
## Should just reuse config.ru.
PROJECT_ROOT = File.join(File.dirname(File.expand_path(__FILE__)), '..')

$: << File.join(PROJECT_ROOT, 'lib')
$: << File.join(PROJECT_ROOT, 'plugins')


require 'rubygems'
require 'mongo_patches'
require 'config'
require 'db'
require 'app'

App::Base::PROJECT_ROOT = PROJECT_ROOT

Dir[File.join(PROJECT_ROOT,'plugins', '*')].each do |p|
  name = File.basename(p)
  require "#{name}/init"
end
####################################

require 'sinatra'
require 'rack/test'

# setup test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true

def app
  App::Base
end

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
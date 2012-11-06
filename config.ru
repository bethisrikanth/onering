ENV['PROJECT_ROOT'] = File.dirname(File.expand_path(__FILE__))

$: << File.join(ENV['PROJECT_ROOT'], 'lib')
$: << File.join(ENV['PROJECT_ROOT'], 'plugins')


require 'rubygems'
require 'mongo_patches'
require 'config'
require 'db'
require 'app'

Dir[File.join(ENV['PROJECT_ROOT'],'plugins', '*')].each do |p|
  name = File.basename(p)
  require "#{name}/init"
end

run App::Base.new

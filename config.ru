$: << File.join(File.dirname(File.expand_path(__FILE__)), 'lib')
$: << File.join(File.dirname(File.expand_path(__FILE__)), 'plugins')

require 'rubygems'
require 'mongo_patches'
require 'app'

Dir[File.join(File.dirname(File.expand_path(__FILE__)),'plugins', '*')].each do |p|
  name = File.basename(p)
  require "#{name}/init"
end


#use App::Jsonify
run App::Base.new
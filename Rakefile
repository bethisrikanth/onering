require 'rubygems'
require 'cucumber'
require 'cucumber/rake/task'

Cucumber::Rake::Task.new(:test) do |t|
desc "Run API backend integration tests"
  t.cucumber_opts = "features plugins/*/features"
end


namespace :db do
  desc "Seeds the db with test/mock data"
  task :seed do
    load "irb.ru"
    require "db/seed"
    puts "Seeding database..."
    App::Database::Seed.seed
  end
  task :clean do
    load "irb.ru"
    require "db/seed"
    puts "Cleaning DB..."
    App::Database::Seed.clean
    puts "done"
  end
end

# utilities for managing static assets
namespace :assets do
  desc "Generate minified production-ready static resources from installed plugins"
  task :generate, :plugins do |t, plugins|
    p = (plugins[:plugins] || Dir["plugins/*"].collect{|d| File.basename(d) }.sort.join(','))
    plugins = p.split(/\W/) unless plugins.is_a?(Array)

  # hack?  yes.
    system "./bin/regen-assets.sh #{plugins.join(' ')}"
  end
end

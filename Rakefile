
begin
  require 'jasmine'
  load 'jasmine/tasks/jasmine.rake'
rescue LoadError
  task :jasmine do
    abort "Jasmine is not available. In order to run jasmine, you must: (sudo) gem install jasmine"
  end
end


task :test do
  ["rspec spec", "rake jasmine:ci"].each do |cmd|
    puts "Starting to run #{cmd}..."
    system("bundle exec #{cmd}")
    raise "#{cmd} failed!" unless $?.exitstatus == 0
  end
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

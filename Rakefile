
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
  load "irb.ru"
  require "db/seed"

  desc "Seeds the db with test/mock data"
  task :seed do
    puts "Seeding database..."
    App::Database::Seed.seed
  end
  task :clean do
    puts "Cleaning DB..."
    App::Database::Seed.clean
    puts "done"
  end
end
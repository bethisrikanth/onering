# Copyright 2014 Outbrain, Inc.
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

require 'rubygems'
require 'rainbow'
require 'cucumber'
require 'cucumber/rake/task'

# Cucumber::Rake::Task.new(:test) do |t|
# desc "Run API backend integration tests"
#   t.cucumber_opts = "features plugins/*/features"
# end

namespace :plugins do
  desc "Downloads and updates the plugins listed in Ringfile to the specified versions"
  task :sync do

  end
end

namespace :launch do
  desc "Prepares the checked out copy for first run"
  task :prep do
    puts "Verifying and/or installing Gem prerequisites...".foreground(:blue)
    system("bundle check || bundle install")

    puts "Generating static assets...".foreground(:blue)
    system("./bin/regen-assets.sh")
  end

  desc "Generate a local copy of the Onering documentation"
  task :docs do
  # generate doc site
    puts "Generating documentation at /docs...".foreground(:blue)

    system("rm -rf _docs && git clone . _docs")
    system("cd _docs && git checkout gh-pages")
    system("cd _docs; jekyll build --config _config.yml,_config.embed.yml --destination ../public/docs")
  end
end


desc "Start an IRB shell with the Onering environment loaded"
task :shell do
  exec("bundle exec racksh")
end


namespace :server do
  desc "Starts a local development server"
  task :start, :port, :env do |t, args|
    require './lib/app'

    port = Integer(args[:port] || 9393)
    env  = (args[:env] || 'development')

    conf = File.expand_path('config.ru', File.dirname(__FILE__))

    Onering::Logger.info("Starting #{env} server on port #{port}")
    Onering::Logger.info("="*80)
    exec("bundle exec thin -e #{env} -R #{conf} --debug -p #{port} start")
  end
end

namespace :worker do
  require 'resque/tasks'

  desc "Starts a Resque backend job worker"
  task :start, :queues do |t, args|
    require './lib/app'

    if ENV['QUEUE'].nil?
      ENV['QUEUE']    = (args[:queues] || ['critical', 'high', 'normal', 'low'].join(','))
    end

    ENV['TERM_CHILD'] = '1'
    ENV['INTERVAL']   = '0.2'

  # set resque logger
    Resque.logger = Logger.new('/dev/null')

  # setup metrics logging
    App::Metrics.setup()
    App::Metrics.increment("worker.process.started")

  # load tasks
    Automation::Tasks::Task.load_all()

    Onering::Logger.info("Starting Resque worker for the following queues: #{ENV['QUEUE']}...", "WORKER")
    Rake::Task['worker:resque:work'].invoke
  end

  namespace :legacy do
    desc "Starts a legacy worker backed by beanstalkd"
    task :start do
      conf = File.expand_path('config.ru', File.dirname(__FILE__))
      exec("bundle exec ./bin/onering-worker")
    end
  end
end

namespace :db do
  desc "Deletes all indices and recreates them empty.  EXTREMELY DANGEROUS!"
  task :nuke, :model do |t,args|
    require './lib/app'

    load "irb.ru"
    puts "Nuking database..."

    App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))
    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      next if args[:model] and args[:model].camelize.constantize != model

      begin
        puts "Deleting model #{model.name}..."

        model.connection.indices.delete_mapping({
          :index => model.index_name(),
          :type  => model.document_type()
        })

        model.get_indices().each do |i|
          puts "-> Removing index #{i}"
          model.connection.indices.delete({
            :index => i
          })
        end
      rescue
        nil
      end
    end
  end

  desc "Syncs the db with the schema defined in the models"
  task :sync, :model do |t,args|
    require './lib/app'
    load "irb.ru"
    puts "Syncing database..."

    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      next if args[:model] and args[:model].camelize.constantize != model

      puts "Syncing model #{model.name}..."
      model.sync_schema()
    end
  end


  desc "Loads the default fixture data from all plugins into the database"
  task :load, :facet do |t, args|
    require './lib/app'

    fixtures = Dir[File.join([ENV['PROJECT_ROOT'], "plugins", "*", "fixtures", args[:facet], "*.json"].compact)]

    if not fixtures.empty?
      Onering::Logger.info("Loading fixtures from #{fixtures.length} files")

      fixtures.each do |fixture|
        Onering::Logger.debug("Loading file #{fixture}")

        json = MultiJson.load(File.read(fixture))

        if json.is_a?(Array) and json.first.is_a?(Hash)
          json.each do |i|
            begin
              klass = (i.delete('_type') || File.basename(fixture, '.json').sub(/s$/,'')).camelize.constantize()
              klass.new.from_h(i,true,false).save()
            rescue
              Onering::Logger.warn("Error processing #{fixture} @ #{i['id']}")
              next
            end
          end
        end
      end
    end
  end

  desc "Destroy and recreate an empty database"
  task :reinitialize => [:nuke, :sync] do
    puts "Reinitialized database"
  end

  desc "Initialize a new index based on the latest generated mapping and move data into it"
  task :reindex, :model, :cleanup do |t, args|
    require './lib/app'

    klass = args[:model].camelize.constantize()
    Onering::Logger.info("Reindexing model #{klass.name}...")

    new_index = klass.reindex({
      :cleanup => args[:cleanup]
    })

    Onering::Logger.info("New index created: #{new_index}")
  end

  desc "Remove all closed indices for a given model or across all models"
  task :prune, :model do |t,args|
    require './lib/app'

    args.with_defaults({
      :model => nil
    })

    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      next if args[:model] and args[:model].camelize.constantize != model

      puts "Pruning model #{model.name}..."
      model.get_closed_indices().each do |i|
        puts "-> deleting closed index #{i}"

        model.connection().indices.delete({
          :index => i
        })
      end

      (model.get_indices() - model.get_real_index()).each do |i|
        puts "-> deleting unreferenced index #{i}"

        model.connection().indices.delete({
          :index => i
        })
      end
    end
  end

  desc "Duplicates an index"
  task :backup, :source, :dest do |t, args|
    require './lib/app'

    if args[:source] and args[:dest]
      puts "Copying #{args[:source]} to #{args[:dest]}..."
      Tensor::Model.copy_index(args[:source], args[:dest])
    end
  end


  desc "Change the data index the given alias points to"
  task :ln, :from, :to do |t, args|
    require './lib/app'

    if args[:from] and args[:to]
      puts "Linking #{args[:to]} -> #{args[:from]}..."
      Tensor::Model.alias_index({
        :index     => args[:to],
        :create    => false,
        :swap      => true,
        :new_index => args[:from]
      })
    end
  end
end

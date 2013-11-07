require 'rubygems'
require 'rainbow'
require 'cucumber'
require 'cucumber/rake/task'
require './lib/app'

Cucumber::Rake::Task.new(:test) do |t|
desc "Run API backend integration tests"
  t.cucumber_opts = "features plugins/*/features"
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

    ENV['QUEUE']      = (args[:queues] || ['critical', 'high', 'normal', 'low'].join(','))
    ENV['TERM_CHILD'] = '1'
    ENV['INTERVAL']   = '0.2'

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
  task :nuke do
    load "irb.ru"
    puts "Nuking database..."

    App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))
    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
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
  task :sync do
    load "irb.ru"
    puts "Syncing database..."

    App::Model::Elasticsearch.configure(App::Config.get('database.elasticsearch', {}))
    models = Hash[App::Model::Elasticsearch.implementers.to_a.collect{|i| [i.index_name, i] }]

    models.each do |index, model|
      puts "Syncing model #{model.name}..."
      model.sync_schema()
    end
  end

  task :reinitialize => [:nuke, :sync] do
    puts "Reinitialized database"
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


# generate CA and Validation SSL
namespace :ssl do
  desc "Generate SSL certificates"

  task :generate do |t|
    ca_base         = './config/ssl/ca'
    validation_pem  = './config/ssl/validation.pem'
    raise "Cannot generate validation certificate, #{validation_pem} already exists!" if File.size?(validation_pem)


    ENV['PROJECT_ROOT'] = File.dirname(File.expand_path(__FILE__))

    require 'openssl'
    require './lib/app'

    App::Config.load(ENV['PROJECT_ROOT'])

    subject         = "#{ App::Config.get!('global.authentication.methods.ssl.subject_prefix').sub(/\/$/,'') }/OU=System/CN=Validation"


  # load CA certificate and keys
    ca_crt = OpenSSL::X509::Certificate.new(File.read("#{ca_base}.crt"))
    ca_key = OpenSSL::PKey::RSA.new(File.read("#{ca_base}.key"))

  # new validation certificate
    validation_crt = OpenSSL::X509::Certificate.new
    validation_crt.subject = OpenSSL::X509::Name.parse(subject)
    validation_crt.issuer = ca_crt.issuer
    validation_crt.not_before = Time.now
    validation_crt.not_after = Time.now + ((Integer(App::Config.get('global.authentication.methods.ssl.client.max_age')) rescue 365) * 24 * 60 * 60)
    validation_crt.public_key = ca_key.public_key
    validation_crt.serial = 0x0
    validation_crt.version = 2

  # add extensions (don't entirely know what these do)
    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = validation_crt
    ef.issuer_certificate = ca_crt

    validation_crt.extensions = [
      ef.create_extension("basicConstraints","CA:TRUE", true),
      ef.create_extension("subjectKeyIdentifier", "hash")
    ]

  # sign it
    validation_crt.sign(ca_key, OpenSSL::Digest::SHA256.new)

  # save it
    File.open(validation_pem, "w") do |f|
      f.write(validation_crt.to_pem)
    end
  end
end

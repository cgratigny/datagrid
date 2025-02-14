require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

require "active_record"
require 'action_view'
require "rails"
require "mongoid"
begin
  require 'mongo_mapper'
rescue LoadError
end



require 'datagrid'
begin
  require 'ruby-debug'
rescue LoadError
end
require 'rspec'
require "logger"

class DatagridTest < Rails::Application

  config.eager_load = false

end

if I18n.respond_to?(:enforce_available_locales)
  I18n.enforce_available_locales = true
end

File.open('spec.log', "w").close
TEST_LOGGER = Logger.new('spec.log')
NO_MONGO = ENV['NO_MONGO']

if NO_MONGO
  warn("MONGODB WARNING: Skipping Mongoid and Mongomapper tests.")
else
  begin
    Mongoid.load_configuration({
      "clients" =>
      {
        "default" =>
        {
          "hosts" => ["localhost:27017"],
          "database" =>"datagrid_mongoid",
          options: {
            max_read_retries: 0,
            retry_reads: false,
            connect_timeout: 2,
            wait_queue_timeout: 2,
            server_selection_timeout: 2,
            socket_timeout: 1
          }
        }
      }
    })

    Mongoid.client(:default).collections # check mongo connection

    if defined?(MongoMapper)
      MongoMapper.connection = Mongo::Connection.new('localhost', 27017)
      MongoMapper.database = "datagrid_mongo_mapper"
    end
  rescue Mongo::Error::NoServerAvailable => e
    warn "Didn't find mongodb at localhost:27017. Run with NO_MONGO=true env variable to skip mongodb tests"
    raise e
  end
end

RSpec.configure do |config|
  config.after(:each) do
    #TODO better database truncation
    Group.delete_all
    Entry.delete_all
    SequelEntry.where({}).delete
    unless NO_MONGO
      MongoidEntry.delete_all
      MongoMapperEntry.delete_all if defined?(MongoMapperEntry)
    end

  end

  if NO_MONGO
    config.filter_run_excluding :mongoid => true
    config.filter_run_excluding :mongomapper => true
  end

  config.expect_with :rspec do |c|
    #c.syntax = :expect
    c.syntax = [:should, :expect]
  end
end

def action_view_template
  context = ActionView::LookupContext.new([
    File.expand_path("../../app/views", __FILE__),
    File.expand_path("../support/test_partials", __FILE__),
  ], {})
  klass = ActionView::Base.respond_to?(:with_empty_template_cache) ? ActionView::Base.with_empty_template_cache : ActionView::Base
  template = klass.new(context, {}, ::ActionController::Base.new)
  allow(template).to receive(:protect_against_forgery?).and_return(false)
  template
end



# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

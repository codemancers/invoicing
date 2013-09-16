require 'test/unit'
require 'rubygems'
require 'active_record'
require 'active_support'
require 'flexmock/test_unit'
require 'pry-rails'

$: << File.join(File.dirname(__FILE__), '..', 'lib')

ActiveSupport::Dependencies.autoload_paths << File.join(File.dirname(__FILE__), 'models')

require 'invoicing'

# Overridden by ../../config/database.yml if it exists.
TEST_DB_CONFIG = {
  :postgresql => {:adapter => "postgresql", :host => "localhost", :database => "invoicing_test",
    :username => "invoicing", :password => "password"},
  :mysql => {:adapter => "mysql", :host => "localhost", :database => "invoicing_test",
    :username => "root", :password => ""}
}
TEST_DB_CONFIG_FILE = File.expand_path(File.join(File.dirname(__FILE__), '..', 'config', 'database.yml'))

def database_used_for_testing
  (ENV['DATABASE'] || :mysql).to_sym
end

def test_in_all_databases
  !!ENV['TEST_ALL_DATABASES']
end

def connect_to_testing_database
  # db_config = TEST_DB_CONFIG[database_used_for_testing]
  # db_config_from_file = false

  # if File.exists? TEST_DB_CONFIG_FILE
  #   yaml = YAML::load File.open(TEST_DB_CONFIG_FILE)
  #   if yaml && yaml['test'] && (yaml['test']['adapter'].to_s == database_used_for_testing.to_s)
  #     db_config = yaml['test']
  #     db_config_from_file = true
  #   end
  # end

  # puts "Connecting to #{database_used_for_testing} with config #{db_config.inspect}" +
  #   (db_config_from_file ? " from #{TEST_DB_CONFIG_FILE}" : "")
  ActiveRecord::Base.establish_connection 'sqlite3:///:memory:'
end

connect_to_testing_database

require File.join(File.dirname(__FILE__), 'setup')


ENV['TZ'] = 'Etc/UTC' # timezone of values in database
ActiveRecord::Base.default_timezone = :utc # timezone of created_at and updated_at
Time.zone = 'Etc/UTC' # timezone for output (when using Time#in_time_zone)


# # Behave a bit like ActiveRecord's transactional fixtures.
# module Test
#   module Unit
#     class TestCase
#       def setup
#         ActiveRecord::Base.connection.increment_open_transactions
#         ActiveRecord::Base.connection.begin_db_transaction
#       end

#       def teardown
#         ActiveRecord::Base.connection.rollback_db_transaction
#         ActiveRecord::Base.connection.decrement_open_transactions
#       end
#     end
#   end
# end

# This file is silently executed before the entire test suite runs, when run by 'rake test'.
# To see its output, set the environment variable VERBOSE=1

require File.join(File.dirname(__FILE__), "test_helper.rb")

fixtures_path = File.expand_path("../fixtures", __FILE__)
Dir.glob(fixtures_path + "/*.rb").each { |f| require f }

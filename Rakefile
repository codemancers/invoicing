# %w[rubygems rake rake/clean fileutils newgem rubigen hoe].each { |f| require f }
%w[rubygems rake rake/clean fileutils  hoe].each { |f| require f }

$: << File.join(File.dirname(__FILE__), '..', 'lib')
require "invoicing"

# Hoe calls Ruby with the "-w" set by default; unfortunately, ActiveRecord (at version 2.2.2
# at least) causes a lot of warnings internally, by no fault of our own, which clutters
# the output. Comment out the following four lines to see those warnings.
class Hoe
  RUBY_FLAGS = ENV['RUBY_FLAGS'] || "-I#{%w(lib .).join(File::PATH_SEPARATOR)}" +
      ((defined?(RUBY_DEBUG) && RUBY_DEBUG) ? " #{RUBY_DEBUG}" : '')
end

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec 'invoicing' do |p|
  p.version = Invoicing::VERSION
  p.developer 'Martin Kleppmann', 'rubyforge@eptcomputing.com'

  p.summary = p.paragraphs_of('README.rdoc', 3).join
  p.description = p.paragraphs_of('README.rdoc', 3..5).join("\n\n")
  p.changes = p.paragraphs_of("History.txt", 0..1).join("\n\n")
  p.post_install_message = 'PostInstall.txt'
  p.rubyforge_name = p.name

  p.extra_deps = [
    ['activerecord', '>= 2.1.0'],
    ['builder', '>= 2.0']
  ]

  p.test_globs = %w[test/*_test.rb] # do not include test/models/*.rb
  p.clean_globs |= %w[**/.DS_Store tmp *.log coverage]
  p.rsync_args = '-av --delete --ignore-errors'
  p.remote_rdoc_dir = 'doc'
end

# require 'newgem/tasks' # load /tasks/*.rake
Dir['tasks/**/*.rake'].each { |t| load t }

# Tasks to run by default
# task :default => [:spec, :features]

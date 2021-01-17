$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'invoicing/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'invoicing'
  s.version     = Invoicing::VERSION
  s.license     = 'MIT'
  s.authors     = ['Martin Kleppmann', 'Codemancers']
  s.email       = ['hello@codemancers.com']
  s.homepage    = 'http://invoicing.codemancers.com/'
  s.summary     = 'Ruby Invoicing Framework'
  s.description = <<-DESC
    This is a framework for generating and displaying invoices (ideal for commercial
     Rails apps). It allows for flexible business logic; provides tools for tax
     handling, commission calculation etc. It aims to be both developer-friendly
     and accountant-friendly.
  DESC

  s.post_install_message = <<-POST_INSTALL
    1.2.x will be the last version to support Ruby < 2.4 and Rails < 5.
    The next version will introduce breaking changes including removal of the `FindSubClasses` class
  POST_INSTALL

  s.files = Dir['{lib}/**/*', 'LICENSE', 'Rakefile', 'README.md']

  s.required_ruby_version = '>= 2.0.0'

  s.add_runtime_dependency 'rails', '>= 3.2.13', '< 5.2'

  s.add_development_dependency 'minitest', '> 4'
  s.add_development_dependency 'sqlite3', '< 1.4'
  s.add_development_dependency 'uuid', '> 2'
end

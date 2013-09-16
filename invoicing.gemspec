$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "invoicing/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "invoicing"
  s.version     = Invoicing::VERSION
  s.authors     = ["Martin Kleppmann"]
  s.email       = ["@martinkl"]
  s.homepage    = "http://ept.github.com/invoicing"
  s.summary     = "Ruby Invoicing Framework"
  s.description = <<-DESC
This is a framework for generating and displaying invoices (ideal for commercial
 Rails apps). It allows for flexible business logic; provides tools for tax
 handling, commission calculation etc. It aims to be both developer-friendly
 and accountant-friendly.
DESC

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_dependency "rails", ">= 3.2.13"

  s.add_development_dependency "hoe"
  s.add_development_dependency "sqlite3"
  s.add_development_dependency "flexmock" # TODO: Remove this dependency
end

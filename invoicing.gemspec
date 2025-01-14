$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "invoicing/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "invoicing"
  s.version     = Invoicing::VERSION
  s.authors     = ["Martin Kleppmann"]
  s.email       = ["@martinkl"]
  s.homepage    = "https://invoicing.c9s.dev/"
  s.summary     = "Ruby Invoicing Framework"
  s.description = <<-DESC
This is a framework for generating and displaying invoices (ideal for commercial
 Rails apps). It allows for flexible business logic; provides tools for tax
 handling, commission calculation etc. It aims to be both developer-friendly
 and accountant-friendly.
DESC

  s.files = Dir["{lib}/**/*", "LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 3.2.13"

  s.add_development_dependency "sqlite3", "< 1.4"
  s.add_development_dependency "minitest"
  s.add_development_dependency "uuid"
end

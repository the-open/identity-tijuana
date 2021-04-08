$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "identity_tijuana/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "identity_tijuana"
  s.version     = IdentityTijuana::VERSION
  s.authors     = ["GetUp!"]
  s.email       = ["tech@getup.org.au"]
  s.homepage    = "https://github.com/GetUp/identity_tijuana"
  s.summary     = "Identity Tijuana Integration."
  s.description = "Push members to Tijuana Tag. Pull Members from Tijuana Tag."
  s.license     = "TBD"

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  s.add_dependency "rails"
  s.add_dependency "pg"
  s.add_dependency "active_model_serializers", "~> 0.10.7"
  s.add_dependency "httpclient"

end

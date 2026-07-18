require_relative "lib/sessy/saas/version"

Gem::Specification.new do |spec|
  spec.name = "sessy-saas"
  spec.version = Sessy::Saas::VERSION
  spec.authors = [ "Marc Köhlbrugge" ]
  spec.summary = "Hosted-edition companion engine for Sessy"
  spec.description = "Rails engine that bundles with Sessy to power the hosted version. Not meant to be used by third parties, but it can serve as inspiration for running Sessy on your own infrastructure."
  spec.homepage = "https://github.com/marckohlbrugge/sessy"
  spec.license = "Nonstandard"
  spec.required_ruby_version = ">= 3.4"

  # Static glob, not `git ls-files`: this gemspec must also resolve inside
  # Docker builds, where .dockerignore excludes the .git directory.
  spec.files = Dir["{app,config,lib}/**/*", "LICENSE.md", "README.md"]

  spec.add_dependency "rails", ">= 8.1"
end

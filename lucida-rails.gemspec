# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name = "lucida-rails"
  s.version = "0.1.0"
  s.summary = "Rails integration for Lucida: Railtie, request-context middleware, install generator"
  s.license = "Apache-2.0"
  s.homepage = "https://github.com/lucidaanalytics/lucida-rails"
  s.metadata = { "source_code_uri" => "https://github.com/lucidaanalytics/lucida-rails", "bug_tracker_uri" => "https://github.com/lucidaanalytics/lucida-rails/issues", "rubygems_mfa_required" => "true" }
  s.authors = ["Lucida"]
  s.required_ruby_version = ">= 3.1"
  s.files = Dir["lib/**/*", "README.md"]
  s.add_dependency "lucida", ">= 0.1"
  s.add_dependency "railties", ">= 6.1"
end

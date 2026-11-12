# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in bindan.gemspec
gemspec

gem "google-cloud-storage", "~> 1.56"
gem "google-cloud-firestore", "~> 3.0"
gem "google-cloud-secret_manager", "~> 2.0.2"
gem "json", "< 3"
gem "cgi", ">= 0.3.5"

gem "rake", "~> 13.0"
gem "minitest", "~> 5.16"
gem "standard", "~> 1.3"

gem "minitest-power_assert", "~> 0.3.1"
gem "power_assert", "~> 2.0"
gem "minitest-reporters", "~> 1.7"

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1")
  gem "steep", "~> 1.10"
end

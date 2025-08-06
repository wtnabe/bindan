# Bindan
[![Gem Version](https://badge.fury.io/rb/bindan.svg)](https://badge.fury.io/rb/bindan)
[![CI](https://github.com/wtnabe/bindan/actions/workflows/test.yml/badge.svg)](https://github.com/wtnabe/bindan/actions/workflows/test.yml)

Bindan is a Ruby gem for building single configuration object from various sources with providers (that is bundled  Google Cloud Storage and Firestore platform by default). It provides a flexible way to manage application settings, supporting lazy initialization and seamless switching between development (using emulators) and production (eg. actual GCP services) environments.

## Features

- **Environment Transparency**: Use the same code for development (with emulators) and production.
- **Multiple Providers**: Fetch configuration from:
  - Environment Variables
  - Google Cloud Storage
  - Google Cloud Firestore
  - your custom provider

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'bindan'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install bindan
```

## Usage

Here is a basic example of how to use Bindan.

### Dead Simple Use

Envvar built-in provider does not need extra code.

```ruby
require "bindan"

config = Bindan.configure do |c, pr|
  c.database_host = pr.env["DATABASE_HOST"] || "localhost"
end

# unless $DATABASE_HOST environment variable
puts config.database_host # => "localhost"
```

or

```ruby
require "bindan"

class App
  extend Bindan
end

App.configure do |c, pr|
  c.database_host = pr.env["DATABASE_HOST"] || "localhost"
end

# unless $DATABASE_HOST environment variable
puts App.config.database_host # => "localhost"
```
### with Multiple Providers

in Gemfile

```ruby
gem "bindan"
gem "google-cloud-storage"
gem "google-cloud-firestore"
```

and

```ruby
require "bindan"
require "google/client/storage"
require "google/client/firestore"

# Define your configuration providers
providers = {
  env: Bindan::Provider::Envvar.new,
  storage: Bindan::Provider::Storage.new(bucket: "my-config-bucket"),
  firestore: Bindan::Provider::Firestore.new(collection: "app-settings")
}

# Configure Bindan
config = Bindan.configure(providers: providers) do |c, pr|
  # Define configuration keys and how they are loaded from providers and fallback
  c.database_host = pr.env["DATABASE_HOST"] || "localhost"
  c.api_key = pr.storage["api_key"]
  c.feature_flags = pr.firestore["feature_flags_document"]
end

# Access your configuration values
puts config.database_host # => "localhost" (or value from ENV["DATABASE_HOST"])
puts config.api_key       # => (Value loaded from Google Cloud Storage)
puts config.feature_flags # => (Value loaded from Firestore)
```

In the `configure` block, you define how each configuration key is mapped to a provider. The provider name is `providers` Hash key.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Prerequisites for Development

This gem is designed to interacts with Google Cloud services as a first-class citizen. For local development and testing, it uses emulators. Please install the following tools:

1.  **Google Cloud CLI:** [Installation the gcloud CLI](https://cloud.google.com/sdk/docs/install)
2.  **Docker:** [Get Docker](https://docs.docker.com/get-docker/)
3.  **Firestore Emulator:**
    ```bash
    gcloud components install cloud-firestore-emulator
    ```
4.  **fake-gcs-server:**
    ```bash
    docker pull fsouza/fake-gcs-server
    ```

### Custom Provider

implement `[]` method.

```ruby
class CustomProvider
  def [](key)
    ...
  end
end
```

### Running Tests

The test suite is configured to automatically start the emulators (including `fake-gcs-server` via Docker), run the tests against them, and shut them down. Simply run:

```bash
bundle exec rake spec
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtnabe/bindan.

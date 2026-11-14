# Bindan
[![Gem Version](https://badge.fury.io/rb/bindan.svg)](https://badge.fury.io/rb/bindan)
[![CI](https://github.com/wtnabe/bindan/actions/workflows/test.yml/badge.svg)](https://github.com/wtnabe/bindan/actions/workflows/test.yml)

Bindan is a Ruby gem for building a single configuration object from various sources with providers (including bundled Google Cloud Storage, Firestore, and Secret Manager providers). It provides a flexible way to manage application settings, supporting lazy initialization and seamless switching between development (using emulators) and production (eg. actual GCP services) environments.

## Features

- **Environment Transparency**: Use the same code for development (with emulators) and production.
- **Multiple Providers**: Fetch configuration from:
  - Environment Variables
  - Google Cloud Storage
  - Google Cloud Firestore
  - Google Cloud Secret Manager
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
gem "google-cloud-secret_manager"
```

and

```ruby
require "bindan"
require "google/cloud/storage"
require "google/cloud/firestore"
require "google/cloud/secret_manager"

# Define your configuration providers
providers = {
  env: Bindan::Provider::Envvar.new,
  storage: Bindan::Provider::Storage.new("config-bucket", project_id: "my-project"),
  firestore: Bindan::Provider::Firestore.new("app-settings-collection", project_id: "my-project"),
  secret: Bindan::Provider::SecretManager.new(project_id: "my-project")
}

# Configure Bindan
config = Bindan.configure(providers: providers) do |c, pr|
  # Define configuration keys and how they are loaded from providers and fallback
  c.database_host = pr.env["DATABASE_HOST"] || "localhost"
  c.api_key = pr.storage["api_key"]
  c.feature_flags = pr.firestore["feature_flags_document"]
  c.api_token = pr.secret["api-token"]
end

# Access your configuration values
puts config.database_host # => "localhost" (or value from ENV["DATABASE_HOST"])
puts config.api_key       # => (Value loaded from Google Cloud Storage)
puts config.feature_flags # => (Value loaded from Firestore)
# Use config.api_token without printing or logging it.
```

In the `configure` block, you define how each configuration key is mapped to a provider. The provider name is `providers` Hash key.

Replace `my-project` with your Google Cloud project ID. Storage joins `project_id` and the bucket argument with `separator` (default: `"-"`), so this example reads the `api_key` object from the existing `my-project-config-bucket` bucket. Firestore reads the `app-settings-collection/feature_flags_document` document in the same project.

Secret Manager also accepts an omitted `project_id:`, using `GOOGLE_CLOUD_PROJECT`
or `GCLOUD_PROJECT` from the environment. An explicit `project_id:` takes precedence.

For update and revert precautions and commands, see
[Secret Manager operations](docs/secret-manager-operations.md).

## Development

After checking out the repo, run `bin/setup` to install development dependencies and pull the emulator images. It does not start the containers.

```bash
bin/setup
```

You can also run `bin/console` for an interactive prompt that will allow you to experiment.

### Prerequisites for Development

The development environment includes the following tools for running heavy integration tests locally:

1.  **Docker with Docker Compose:** [Get Docker](https://docs.docker.com/get-docker/), with its daemon running.
2.  **Emulators:** `compose.yml` defines fake-gcs-server, the official Google Cloud CLI Firestore emulator image, and the unofficial Secret Manager emulator. Java and Firestore are provided inside the image; no host Java or Google Cloud CLI installation is required. Storage fixtures are mounted directly from `spec/support/storage`.

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

Use the lightweight unit tests during normal development. They do not start emulators:

```bash
bundle exec rake spec
```

Run the heavy integration tests locally when verifying Provider behavior against the real SDKs and emulators. Start the containers explicitly before running the suite:

```bash
docker compose up --detach --wait
bundle exec rake spec:integration
```

The tests wait for readiness but never start or stop containers. Stop them yourself when no longer needed:

```bash
docker compose down
```

CI runs both suites and manages Compose startup, logs and cleanup in the workflow, including cleanup after failures.

Integration tests run serially against Storage on `127.0.0.1:4443`, Firestore on
`127.0.0.1:8080`, and Secret Manager on `127.0.0.1:9090`. Each Firestore case clears
the `bindan-test` project's default database before seeding data. Secret Manager
cases clear secrets in the `bindan-test` project before and after each case.
Use these emulators for disposable, non-sensitive test data only.
The Firestore and Secret Manager controllers wait for an SDK request to succeed,
not merely a TCP connection. The suite does not import or export emulator data.
To use dummy Storage credentials without local GCP credentials, run
`CI=true bundle exec rake spec:integration`.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wtnabe/bindan.

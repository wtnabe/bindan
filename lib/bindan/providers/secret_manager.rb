# frozen_string_literal: true

require "logger"
begin
  require "google/cloud/secret_manager"
  require "google/cloud/secret_manager/v1"
rescue LoadError => e
  warn e
  module Google
    module Cloud
      module SecretManager
        module V1
          module SecretManagerService
            class Client
              def initialize(**kwargs)
              end

              def access_secret_version(**kwargs)
                Struct.new(:payload).new(Struct.new(:data).new)
              end
            end
          end
        end
      end
    end
  end
end

module Bindan
  module Provider
    class SecretManager
      #
      # Create a reader for global secrets in the supplied or environment project.
      # Discard SDK request/response logs to avoid exposing secret values.
      # Use a null logger: GAPIC treats nil as inheriting the default logger.
      #
      # @param [String, nil] project_id project ID or number; defaults to
      #   GOOGLE_CLOUD_PROJECT, then GCLOUD_PROJECT
      # @param [Object] sdk client factory yielding configuration
      # @param [Hash] kwargs SDK client settings (logger is always discarded)
      #
      def initialize(project_id: nil, sdk: ::Google::Cloud::SecretManager::V1::SecretManagerService::Client, **kwargs)
        @project_id = project_id || ENV["GOOGLE_CLOUD_PROJECT"] || ENV["GCLOUD_PROJECT"]
        @_secret_manager = sdk.new do |config|
          kwargs.each { |key, value| config.public_send(:"#{key}=", value) }
          config.logger = Logger.new(nil)
        end
      end
      attr_reader :project_id

      #
      # Read the latest payload without caching or modifying its bytes.
      #
      # @param [String] key secret ID
      # @return [String] secret payload bytes
      # @raise [Google::Cloud::Error] when the SDK reports a service error
      #
      def [](key)
        name = "projects/#{@project_id}/secrets/#{key}/versions/latest"
        @_secret_manager.access_secret_version(name: name).payload.data
      end
    end
  end
end

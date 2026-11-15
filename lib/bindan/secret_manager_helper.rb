# frozen_string_literal: true

require "logger"
require "google/cloud/secret_manager/v1"

module Bindan
  #
  # Add versions separately from the read-only Secret Manager Provider.
  # SDK errors propagate; avoid logging exception details that may contain secrets.
  # A failed operation may have created a version; check before retrying.
  #
  # @example Use the helper directly without the CLI
  #   require "bindan/secret_manager_helper"
  #
  #   helper = Bindan::SecretManagerHelper.new(project_id: "my-project")
  #   previous = helper.last_version("api-key")
  #   created = helper.update("api-key", data: File.binread("./api-key.bin"))
  #   previous&.name # Last created version before the update, if any.
  #   created.name   # The newly created version.
  #   restored = helper.revert("api-key", version: 1)
  #
  class SecretManagerHelper
    #
    # Create a helper for adding versions of existing global secrets.
    # Suppress SDK request/response logging and automatic write retries.
    #
    # @param [String, nil] project_id project ID or number; defaults to
    #   GOOGLE_CLOUD_PROJECT, then GCLOUD_PROJECT
    # @param [Object] sdk client factory yielding configuration
    # @param [Hash] kwargs SDK client settings (logger and retry policies are overridden)
    #
    def initialize(project_id: nil, sdk: ::Google::Cloud::SecretManager::V1::SecretManagerService::Client, **kwargs)
      @project_id = project_id || ENV["GOOGLE_CLOUD_PROJECT"] || ENV["GCLOUD_PROJECT"]
      @_secret_manager = sdk.new do |config|
        kwargs.each { |key, value| config.public_send(:"#{key}=", value) }
        config.logger = Logger.new(nil)
        # GAPIC applies client-wide defaults after RPC defaults. Clear both so
        # a caller-supplied retry policy cannot retry a version-creating write.
        config.retry_policy = nil
        config.rpcs.add_secret_version.retry_policy = nil
      end
    end
    # @return [String, nil] explicit or environment project ID or number
    attr_reader :project_id

    #
    # Read metadata for the last created version, regardless of its state.
    # This does not resolve the latest alias. Listing is eventually consistent.
    #
    # @param [String] secret_id ID of an existing secret
    # @return [Google::Cloud::SecretManager::V1::SecretVersion, nil] last created version, or nil if none
    # @raise [Google::Cloud::Error] when the SDK reports a service error
    #
    def last_version(secret_id)
      parent = "projects/#{@project_id}/secrets/#{secret_id}"
      @_secret_manager.list_secret_versions(parent: parent).first
    end

    #
    # Add the exact bytes as a new version and return the SDK's creation result.
    # SDK failures propagate unchanged; no operation is retried here.
    #
    # @param [String] secret_id ID of an existing secret
    # @param [String] data secret payload bytes
    # @return [Google::Cloud::SecretManager::V1::SecretVersion] created version metadata
    # @raise [Google::Cloud::Error] when the SDK reports a service error
    #
    def update(secret_id, data:)
      parent = "projects/#{@project_id}/secrets/#{secret_id}"
      @_secret_manager.add_secret_version(parent: parent, payload: {data: data.b})
    end

    #
    # Copy an existing numerical version into a new version.
    #
    # @param [String] secret_id ID of an existing secret
    # @param [String, Integer] version known-good positive numerical version, not an alias
    # @return [Google::Cloud::SecretManager::V1::SecretVersion] created version metadata
    # @raise [ArgumentError] when version is not a positive numerical version
    # @raise [Google::Cloud::Error] when the SDK reports a service error
    #
    def revert(secret_id, version:)
      unless /\A[1-9][0-9]*\z/.match?(version.to_s)
        raise ArgumentError, "Secret version must be a positive numerical version"
      end

      name = "projects/#{@project_id}/secrets/#{secret_id}/versions/#{version}"
      data = @_secret_manager.access_secret_version(name: name).payload.data
      update(secret_id, data: data)
    end
  end
end

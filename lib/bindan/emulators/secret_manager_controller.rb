require "google/cloud/secret_manager/v1"
require "grpc"
require "logger"

module Bindan
  module Emulator
    #
    # Checks readiness and clears local test data without managing containers.
    #
    class SecretManagerController
      WAIT_TIMEOUT = 60 # seconds

      class Error < StandardError; end

      attr_reader :project_id, :client

      #
      # Connect to the local emulator without authentication or payload logging.
      #
      # @param [String] project_id project whose test secrets may be deleted
      #
      def initialize(project_id: "bindan-test")
        @project_id = project_id
        @channel = GRPC::Core::Channel.new(endpoint, {}, :this_channel_is_insecure)
        # @type var retry_codes: Array[Integer]
        retry_codes = []
        @client = Google::Cloud::SecretManager::V1::SecretManagerService::Client.new do |config|
          config.endpoint = endpoint
          config.credentials = @channel
          config.logger = Logger.new(nil)
          config.timeout = 2
          config.retry_policy = {retry_codes: retry_codes}
        end
      end

      #
      # @return [String] loopback SDK endpoint (host:port, without an HTTP scheme)
      #
      def endpoint
        "127.0.0.1:9090"
      end

      #
      # Wait for an SDK list request to succeed, retrying transient failures.
      #
      # @param [Numeric] timeout readiness deadline in seconds
      # @return [self] after a successful SDK read
      # @raise [Error] when the readiness deadline expires between attempts
      #
      def wait_available(timeout: WAIT_TIMEOUT)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise Error, "Secret Manager emulator readiness timed out" unless remaining > 0
          return self if sdk_ready?([remaining, 2].min)
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep [0.1, remaining].min if remaining > 0
        end
      end

      #
      # Delete all secrets and their versions in the selected test project.
      # Collect names before deleting so pagination cannot skip entries.
      #
      # @return [self] after all listed secrets have been deleted
      #
      def clear
        client.list_secrets(parent: "projects/#{project_id}").to_a.each do |secret|
          client.delete_secret(name: secret.name)
        end
        self
      end

      #
      # Release the shared gRPC channel after the integration run.
      #
      # @return [void]
      #
      def close
        @channel.close
      end

      private

      #
      # Probe the list API; only unavailable/deadline errors become false.
      #
      # @param [Numeric] timeout per-request timeout in seconds
      # @return [Boolean] true on success, false on a transient startup failure
      #
      def sdk_ready?(timeout)
        # @type var retry_codes: Array[Integer]
        retry_codes = []
        client.list_secrets(
          {parent: "projects/#{project_id}", page_size: 1},
          {timeout: timeout, retry_policy: {retry_codes: retry_codes}}
        ).each { |_| }
        true
      rescue Google::Cloud::UnavailableError, Google::Cloud::DeadlineExceededError
        false
      end
    end
  end
end

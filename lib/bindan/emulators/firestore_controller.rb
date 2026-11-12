require_relative "../error"
require "net/http"
require "timeout"

module Bindan
  module Emulator
    #
    # Represents and controls a single instance of the Google Cloud Firestore emulator service.
    # This class checks readiness and clears test data without managing containers.
    #
    class FirestoreController
      WAIT_TIMEOUT = 60 # seconds
      INITIAL_BACKOFF_KEY_SEC = 0.1 # seconds
      BACKOFF_MULTIPLIER = 1.5

      class Error < StandardError; end

      attr_reader :project_id

      #
      # Select the project used by the integration tests.
      #
      def initialize(project_id: "bindan-test")
        @project_id = project_id
      end

      #
      # @return [String] SDK endpoint (host:port, without an HTTP scheme)
      #
      def endpoint
        "127.0.0.1:8080"
      end

      #
      # Wait for an SDK read, retrying false with bounded exponential backoff.
      #
      # @return [self] after a successful SDK read
      # @raise [Error] when the overall deadline expires, including during a check
      # @param [number] timeout
      # @param [number] backoff
      # @param [number] multiplier
      # Failures/interruption propagate; container lifecycle is managed externally.
      #
      def wait_available(timeout: WAIT_TIMEOUT, backoff: INITIAL_BACKOFF_KEY_SEC, multiplier: BACKOFF_MULTIPLIER, with_message: true)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        @readiness_error = nil
        puts "   Waiting for Firestore SDK on #{endpoint}..." if with_message
        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise Error, "Firestore readiness timed out: #{@readiness_error}" unless remaining > 0
          return self if Timeout.timeout(remaining) { sdk_ready?([remaining, 2].min) }
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          sleep [backoff, remaining].min if remaining > 0
          backoff *= multiplier
        end
      rescue Timeout::Error => error
        raise Error, "Firestore readiness timed out: #{error.message}"
      end

      #
      # Clear only this project's default database and wait for DELETE completion.
      #
      # @return [self] after HTTP 200, before the next test seeds any data
      # @raise [Error] for an unsuccessful HTTP status
      # HTTP/timeout errors propagate; no lifecycle or other-project operations occur.
      #
      def clear(timeout: 10)
        path = "/emulator/v1/projects/#{project_id}/databases/(default)/documents"
        response = Timeout.timeout(timeout) { delete_documents(path, timeout) }
        raise Error, "Firestore clear #{project_id} failed: HTTP #{response.code}: #{response.body}" unless response.code == "200"
        self
      end

      private

      #
      # Check a read through the V1 public API, with per-call timeout and no SDK retry.
      # Keep this lower-level boundary here: high-level doc.get can retry past its timeout.
      #
      # @return [Boolean] true on a completed read (a missing document is also valid),
      #   false only for transient unavailable/deadline errors during startup
      # Other SDK/configuration errors propagate; no document is written.
      # Each attempt closes its channel; wait_available also enforces an overall deadline.
      #
      def sdk_ready?(timeout)
        require "google/cloud/firestore/v1"
        require "grpc"
        channel = GRPC::Core::Channel.new(endpoint, {}, :this_channel_is_insecure)
        client = Google::Cloud::Firestore::V1::Firestore::Client.new do |config|
          config.endpoint = endpoint
          config.credentials = channel
        end
        database = "projects/#{project_id}/databases/(default)"
        client.batch_get_documents(
          {database: database, documents: ["#{database}/documents/bindan-control/readiness"]},
          {timeout: timeout, retry_policy: {retry_codes: []}}
        ).each { |_| }
        @readiness_error = nil
        true
      rescue Google::Cloud::UnavailableError, Google::Cloud::DeadlineExceededError => error
        @readiness_error = error
        false
      ensure
        channel&.close
      end

      #
      # Send clear's local DELETE without environment proxies or redirect following.
      #
      # @return [Net::HTTPResponse] the completed response; clear validates its status
      # Connection and timeout errors propagate to the caller.
      #
      def delete_documents(path, timeout)
        http = Net::HTTP.new("127.0.0.1", 8080, nil) # Explicitly disable environment proxies.
        http.open_timeout = timeout
        http.read_timeout = timeout
        http.write_timeout = timeout
        http.request(Net::HTTP::Delete.new(path))
      end
    end
  end
end

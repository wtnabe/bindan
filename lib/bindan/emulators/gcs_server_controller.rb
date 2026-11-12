require_relative "../error"
require "net/http"
require "timeout"

module Bindan
  module Emulator
    class GcsServerController
      class ContainerCannotOpenError < Error; end

      WAIT_TIMEOUT = 15 # seconds
      INITIAL_BACKOFF_KEY_SEC = 0.1 # seconds
      BACKOFF_MULTIPLIER = 1.5

      #
      # @return [bool]
      #
      def running?
        read_status.code == "200"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, Net::OpenTimeout, Net::ReadTimeout
        false
      end

      #
      # waits container to be running
      #
      # @raise [ContainerCannotOpenError] if the container does not become available within the configured timeout.
      # @param [number] timeout
      # @param [number] backoff
      # @param [number] multiplier
      # @return [self]
      #
      def wait_available(timeout: WAIT_TIMEOUT, backoff: INITIAL_BACKOFF_KEY_SEC, multiplier: BACKOFF_MULTIPLIER)
        Timeout.timeout(timeout) do
          loop do
            return self if running?
            sleep backoff
            backoff *= multiplier
          end
        end
      rescue Timeout::Error
        raise ContainerCannotOpenError, "Storage readiness timed out"
      end

      private

      # Query the published loopback endpoint without environment proxies.
      # @return [Net::HTTPResponse] completed response; connection errors propagate
      def read_status
        http = Net::HTTP.new("127.0.0.1", 4443, nil)
        http.open_timeout = 2
        http.read_timeout = 2
        http.get("/storage/v1/b")
      end
    end
  end
end

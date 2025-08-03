require_relative "../error"
require "fileutils"
require "timeout"
require "open3"

module Bindan
  module Emulator
    class GcsServerController
      class ContainerCannotOpenError < Error; end

      CONTAINER_NAME = "gcs-server"
      WAIT_TIMEOUT = 15 # seconds
      INITIAL_BACKOFF_KEY_SEC = 0.1 # seconds
      BACKOFF_MULTIPLIER = 1.5

      class << self
        #
        # @raise [Errno]
        # @param [String] folder
        # @param [Integer] [port]
        # @param [String] [name]
        # @return [GcsServerController]
        #
        def start(folder:, port: 4443, name: CONTAINER_NAME, close_io: true)
          FileUtils.mkdir_p(folder)
          unless running?(name: name)
            opts = close_io ? {out: "/dev/null", err: "/dev/null"} : {}
            Process.spawn( # steep:ignore
              *"docker run --rm --name #{name} -p #{port}:4443 -v #{folder}:/data fsouza/fake-gcs-server -scheme http".split(" "),
              **opts
            )
          end

          new(name: name, folder: folder)
        end

        #
        # @raise [IOError]
        # @param [String] name
        # @return [bool]
        #
        def running?(name:)
          _stdin, stdout, stderr, = Open3.popen3("docker container list -f name=#{name}")

          begin
            # container list not only headers
            stdout.readlines.size > 1
          rescue IOError => e
            warn "in #{self}"
            warn "   " + stderr.read
            raise ContainerCannotOpenError.new e
          end
        end

        #
        # @param [String] name
        # @raise [Errno]
        # @return [void]
        #
        def stop(name:)
          `docker container stop #{name}`
        end
      end # of class methods

      #
      # @param [String] name
      # @param [String] folder
      #
      def initialize(name:, folder:)
        @container_name = name
        @folder = folder
      end

      #
      # @return
      #
      def stop
        self.class.stop(name: @container_name)
      end

      #
      # @param [String] name
      # @return [bool]
      #
      def running?
        self.class.running?(name: @container_name)
      end

      #
      # waits container to be running
      #
      # @raise [ContainerCannotOpenError] if the container does not become available within the configured timeout.
      # @param [number] timeout
      # @param [number] backoff
      # @param [number] multiplier
      # @return [void]
      #
      def wait_available(timeout: WAIT_TIMEOUT, backoff: INITIAL_BACKOFF_KEY_SEC, multiplier: BACKOFF_MULTIPLIER)
        last_rescued_error = nil

        count = 1
        Timeout.timeout(timeout) do
          loop do
            if running?
              return
            end
          rescue ContainerCannotOpenError => e
            last_rescued_error = e
            sleep backoff
            count += 1
            backoff *= multiplier**count
          end
        end
      rescue Timeout::Error
        raise last_rescued_error # steep:ignore
      end
    end
  end
end

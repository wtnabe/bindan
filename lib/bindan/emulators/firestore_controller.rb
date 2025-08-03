require_relative "../error"
require "fileutils"
require "open3"
require "socket"
require "timeout"
require "uri"

module Bindan
  module Emulator
    #
    # Represents and controls a single instance of the Google Cloud Firestore emulator process.
    # This class encapsulates the logic for starting, stopping, and waiting for the emulator,
    # separating process management from the test execution flow.
    #
    class FirestoreController
      WAIT_TIMEOUT = 15 # seconds
      INITIAL_BACKOFF_KEY_SEC = 0.1 # seconds
      BACKOFF_MULTIPLIER = 1.5

      class << self
        #
        # @return [Array<String, Integer>]
        #
        def host_and_port(host = nil, port = nil)
          host, port = ENV["FIRESTORE_EMULATOR_HOST"].to_s.split(":") if ENV["FIRESTORE_EMULATOR_HOST"]

          host ||= ENV["CI"] ? "0.0.0.0" : "localhost"
          port ||= 8080

          [host, port]
        end

        #
        # Initiates the emulator process and returns a new instance.
        #
        # @param [String] import
        # @param [String] export
        # @param [String] host
        # @param [Integer] port
        # @param [bool] close_io
        # @raise [Errno]
        # @return [FirestoreEmulatorController] An instance to manage the emulator lifecycle.
        #
        def start(import: nil, export: nil, host: nil, port: nil, close_io: true)
          host, port = host_and_port(host, port)

          puts " Starting Firestore emulator ..." unless close_io
          kill_process_if_already_exists(host: host, port: port, with_message: !close_io)

          #
          # This command is known to launch a background Java process and then exit.
          # Trying keep process info with process group
          #
          cmd = "gcloud emulators firestore start --host-port=#{host}:#{port}"
          cmd += " --import-data=#{import}" if import
          cmd += " --export-on-exit=#{export}" if export
          opts = close_io ? {out: "/dev/null", err: "/dev/null"} : {}
          pid = Process.spawn(*cmd, pgroup: true, **opts) # steep:ignore

          puts "   Emulator process initiated." unless close_io
          new(pid, host, port)
        end

        #
        # kill process group
        #
        # @param [Integer] pid
        # @param [bool] with_message
        # @return [void]
        #
        def stop(pid, with_message: true)
          puts "\n=> Stopping Firestore emulator..." if with_message

          begin
            Process.kill("TERM", -pid)
            Process.wait(-pid)
          rescue Errno::ESRCH, Errno::ECHILD
            # Process was already killed or doesn't exist, which is fine.
          end

          puts "   Emulator process terminated." if with_message
        end

        #
        # @param [Integer] host
        # @param [Integer] port
        #
        def kill_process_if_already_exists(host:, port:, with_message: true)
          TCPSocket.new(host, port).close

          # `lsof -Fg -i:PORT` returns PIDs of the process listening on the port.
          process_ids, = Open3.capture3(*"lsof -Fg -g -s TCP:LISTEN -i :#{port}".split(" "))
          process_group = process_ids.lines.map(&:chomp).find { |id| id =~ /^g([0-9]+)/ }

          if process_group
            id = process_group[1..].to_i # strip first letter
            puts "   Found emulator process group #{id} on port #{port}. Terminating." if with_message
            stop(id, with_message: false)
          end
        rescue Errno::ECONNREFUSED
          # noop
        end
      end # of class methods

      #
      # @param [Integer] pid - process group id
      #
      def initialize(pid, host, port)
        @pid = pid
        @host = host
        @port = port
      end

      #
      # waits to accessable
      #
      # @raise [Timeout::Error] if the emulator does not become available within the configured timeout.
      # @param [number] timeout
      # @param [number] backoff
      # @param [number] multiplier
      # @return [void]
      #
      def wait_available(timeout: WAIT_TIMEOUT, backoff: INITIAL_BACKOFF_KEY_SEC, multiplier: BACKOFF_MULTIPLIER, with_message: true)
        last_rescue_error = nil

        puts "   Waiting for emulator to be ready on #{@host}:#{@port}..." if with_message
        count = 1
        Timeout.timeout(timeout) do
          loop do
            TCPSocket.new(@host, @port).close
            puts "   Emulator is up and listening." if with_message
            return
          rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL => e
            last_rescue_error = e
            sleep backoff
            count += 1
            backoff *= multiplier**count
          end
        end
      rescue Timeout::Error
        raise last_rescue_error # steep:ignore
      end

      #
      # @return [void]
      #
      def stop(with_message: true)
        self.class.stop(@pid, with_message: with_message)
      end
    end
  end
end

# frozen_string_literal: true

require "optparse"

module Bindan
  class SecretUpdateCommand
    USAGE = <<~TEXT
      Usage: bindan-secret-update --secret SECRET_ID [--project PROJECT] (--file PATH | --from-version NUMBER)

      Add a new version of an existing global Secret Manager secret.
      --file preserves all bytes, including trailing newlines. Values are never printed.
      --from-version copies a known-good numeric version into a new version.
      Project defaults to GOOGLE_CLOUD_PROJECT, then GCLOUD_PROJECT.
      Success prints the created version name; failure exits nonzero without retrying.
    TEXT

    #
    # @param [Proc, nil] helper_factory factory accepting project_id:; defaults to SecretManagerHelper
    # @param [IO] stdout destination for help and created version names
    # @param [IO] stderr destination for errors without secret values
    #
    def initialize(helper_factory: nil, stdout: $stdout, stderr: $stderr)
      @helper_factory = helper_factory || ->(**options) {
        require_relative "secret_manager_helper"
        SecretManagerHelper.new(**options)
      }
      @stdout = stdout
      @stderr = stderr
    end

    #
    # Parse arguments without performing I/O or modifying argv.
    #
    # @param [Array<String>] argv command-line arguments
    # @return [Hash{Symbol => String, true}] parsed options, including :help when requested
    # @raise [OptionParser::ParseError] when arguments are invalid or required options are missing
    #
    def self.parse(argv)
      # @type var options: Hash[Symbol, untyped]
      options = {}
      parser = OptionParser.new do |opts|
        opts.banner = USAGE
        opts.on("--secret SECRET_ID") { |value| options[:secret] = value }
        opts.on("--project PROJECT") { |value| options[:project_id] = value }
        opts.on("--file PATH") { |value| options[:file] = value }
        opts.on("--from-version NUMBER") { |value| options[:version] = value }
        opts.on("-h", "--help") { options[:help] = true }
      end
      remaining = parser.parse(argv.dup)
      return options if options[:help]

      unless remaining.empty? && options[:secret] && (!!options[:file] != !!options[:version])
        raise OptionParser::InvalidArgument, "Specify a secret and either a file or a source version"
      end
      options
    end

    #
    # Add a version from file bytes or an existing numerical version.
    # Error messages from files, credentials and SDKs may contain sensitive data.
    # Keep those details out of the command's output, including backtraces.
    #
    # @param [Array<String>] argv command-line arguments
    # @return [Integer] exit status: 0 for success/help, 2 for argument errors, 1 for operational failures
    #
    def run(argv)
      options = self.class.parse(argv)
      if options[:help]
        @stdout.puts USAGE
        return 0
      end

      # Read the entire file before creating a client or attempting a write.
      data = File.binread(options[:file]) if options[:file]
      helper = @helper_factory.call(project_id: options[:project_id])
      version = if options[:file]
        helper.update(options[:secret], data: data)
      else
        helper.revert(options[:secret], version: options[:version])
      end
      @stdout.puts version.name
      0
    rescue OptionParser::ParseError
      @stderr.puts USAGE
      2
    rescue LoadError
      @stderr.puts "Secret Manager SDK unavailable. Install google-cloud-secret_manager."
      1
    rescue
      @stderr.puts "Secret update failed. A version may have been created; check the target before retrying."
      1
    end
  end
end

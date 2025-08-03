require_relative "../error"
require "uri"
begin
  require "google/cloud/storage"
rescue LoadError => e
  warn e
  module Google
    module Cloud
      class Storage
        def initialize(**kwargs)
        end

        def bucket(*args)
          Class.new do
            def file(*args)
              Class.new do
                def download(*args)
                end
              end.new
            end
          end.new
        end
      end
    end
  end
end

module Bindan
  module Provider
    class Storage
      class FileNotExist < Error; end

      #
      # @param [String] bucket
      # @param [String] project_id
      # @param [String] separator
      # @param [String] credentials
      # @param [Google::Cloud::Storage] sdk
      #
      def initialize(bucket, raise_error: nil, separator: "-", sdk: ::Google::Cloud::Storage, **kwargs)
        @_options = {}
        @bucket = bucket

        @_options[:raise_error] = raise_error
        @separator = separator
        @project_id = kwargs[:project_id]

        options = prepare_options(kwargs)

        @_storage = sdk.new(**options)
      end
      attr_reader :project_id, :separator

      #
      # @param [Hash] options
      # @return [Hash]
      #
      def prepare_options(options)
        if ENV["STORAGE_EMULATOR_HOST"]
          u = URI(ENV["STORAGE_EMULATOR_HOST"].to_s)
          u.path = "/" if u.path.to_s.size == 0
          options[:endpoint] = u.to_s
        end

        options
      end

      #
      # decorated bucket name
      #
      # @return [String]
      #
      def bucket
        [@project_id, @bucket].join(@separator)
      end

      #
      # @raise FileNotExist
      # @param [String] file
      # @return [String]
      #
      def [](file)
        remote = @_storage.bucket(bucket).file(file)

        if remote
          Tempfile.open { |t|
            remote.download(t.path)
            t.read.chomp
          }
        elsif @_options[:raise_error]
          raise FileNotExist.new file
        end
      end
    end
  end
end

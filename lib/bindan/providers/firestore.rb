require_relative "../error"
begin
  require "google/cloud/firestore"
rescue LoadError => e
  warn e
  module Google
    module Cloud
      class Firestore
        def initialize(**kwargs)
        end

        def doc(*args)
          Class.new do
            def create(*args)
            end

            def get
              Class.new do
                def data
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
    class Firestore
      class ColOrDocNotExist < Error; end

      #
      # 1. Supply collection when registering the provider to avoid repeating it
      #    on each document lookup.
      # 2. Omit collection to access multiple collections through one provider.
      #    Each lookup must then explicitly supply a full document path
      #    (collection/document).
      #
      # Path examples (collection, key -> document path):
      # - "app-settings", "flags"       -> "app-settings/flags"
      # - omitted, "app-settings/flags" -> "app-settings/flags"
      # - omitted, "maintenance/status" -> "maintenance/status"
      # - "app-settings", "other/flags" -> "app-settings/other/flags" (invalid)
      # - omitted, "flags"              -> "/flags" (invalid)
      #
      # @param [String, nil] collection fixed collection path, or nil for full-path keys
      # @param [bool] raise_error
      # @param [Google::Cloud::Firestore] sdk
      #
      def initialize(collection = nil, project_id: nil, raise_error: false, sdk: ::Google::Cloud::Firestore, **kwargs)
        if ENV["FIRESTORE_EMULATOR_HOST"]
          project_id ||= "project"
        end

        @_options = {}
        @collection = collection

        @_options[:raise_error] = raise_error
        @project_id = project_id

        @_firestore = sdk.new(project_id: project_id, **kwargs)
      end
      attr_reader :project_id

      #
      # @param [Hash] pair
      #
      def _prepare(pair)
        path, doc = pair.to_a.flatten

        @_firestore.doc(path).create(doc)
      end

      #
      # @param [String] key document ID/path relative to collection, or full path if omitted
      # @return [String]
      #
      def document_path(key)
        if @collection.nil? && key.include?("/")
          key
        else
          [@collection, key].join("/")
        end
      end

      #
      # @raise ColOrDocNotExist
      # @param [String] key document ID/path relative to collection, or full path if omitted
      # @return [Hash]
      #
      def [](key)
        doc_path = document_path(key)
        doc = @_firestore.doc(doc_path).get

        if @_options[:raise_error] && !doc.data
          raise ColOrDocNotExist.new doc_path
        else
          doc.data
        end
      end
    end
  end
end

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
      # @param [String] collection
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
      # @raise ColOrDocNotExist
      # @param [String] key
      # @return [Hash]
      #
      def [](key)
        doc_path =
          if @collection.nil? && key.include?("/")
            key
          else
            [@collection, key].join("/")
          end

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

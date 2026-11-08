require "spec_helper"

class FirestoreSdkInitializationStub
  attr_reader :options

  def new(**options)
    @options = options
    nil
  end
end

describe Bindan::Provider::Firestore do
  before {
    @emulator_host = ENV.delete("FIRESTORE_EMULATOR_HOST")
    @sdk = FirestoreSdkInitializationStub.new
  }

  after {
    ENV["FIRESTORE_EMULATOR_HOST"] = @emulator_host
  }

  describe "#document_path" do
    describe "collection is supplied" do
      before {
        @provider = Bindan::Provider::Firestore.new("app-settings", sdk: @sdk)
      }

      it "prefixes the document ID with the collection" do
        assert {
          @provider.document_path("flags") == "app-settings/flags"
        }
      end

      it "keeps nested document paths relative to the collection" do
        assert {
          @provider.document_path("parent/children/child") == "app-settings/parent/children/child"
        }
      end
    end

    describe "collection is omitted" do
      before {
        @provider = Bindan::Provider::Firestore.new(sdk: @sdk)
      }

      it "accepts full document paths across collections" do
        assert {
          @provider.document_path("app-settings/flags") == "app-settings/flags"
        }
        assert {
          @provider.document_path("maintenance/status") == "maintenance/status"
        }
      end

      it "does not infer a collection from a bare document ID" do
        assert {
          @provider.document_path("flags") == "/flags"
        }
      end
    end
  end

  describe "#initialize" do
    describe "FIRESTORE_EMULATOR_HOST is not set" do
      it "leaves project resolution to the SDK when project_id is omitted" do
        Bindan::Provider::Firestore.new(sdk: @sdk)
        assert {
          @sdk.options == {project_id: nil}
        }
      end

      it "passes the explicitly supplied project_id to the SDK" do
        Bindan::Provider::Firestore.new(sdk: @sdk, project_id: "my-project")
        assert {
          @sdk.options == {project_id: "my-project"}
        }
      end
    end

    describe "FIRESTORE_EMULATOR_HOST is set" do
      before {
        ENV["FIRESTORE_EMULATOR_HOST"] = "localhost:8080"
      }

      it "supplies the emulator project when project_id is omitted" do
        Bindan::Provider::Firestore.new(sdk: @sdk)
        assert {
          @sdk.options == {project_id: "project"}
        }
      end

      it "keeps the explicitly supplied project_id" do
        Bindan::Provider::Firestore.new(sdk: @sdk, project_id: "my-project")
        assert {
          @sdk.options == {project_id: "my-project"}
        }
      end
    end
  end
end

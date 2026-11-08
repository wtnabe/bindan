require "spec_helper"
require_relative "../support/sdk_initialization_stub"

describe Bindan::Provider::Storage do
  before {
    @emulator_host = ENV.delete("STORAGE_EMULATOR_HOST")
    @sdk = SdkInitializationStub.new
    @provider = Bindan::Provider::Storage.new("config", sdk: @sdk)
  }

  after {
    ENV["STORAGE_EMULATOR_HOST"] = @emulator_host
  }

  describe "#bucket" do
    describe "project_id is omitted" do
      it "keeps the leading default separator" do
        assert {
          @provider.bucket == "-config"
        }
      end

      it "uses the literal bucket name when separator is empty" do
        provider = Bindan::Provider::Storage.new("config", sdk: @sdk, separator: "")
        assert {
          provider.bucket == "config"
        }
      end
    end

    describe "project_id is supplied" do
      it "joins the project ID and bucket with the default separator" do
        provider = Bindan::Provider::Storage.new("config", sdk: @sdk, project_id: "staging")
        assert {
          provider.bucket == "staging-config"
        }
      end

      it "uses the supplied separator" do
        provider = Bindan::Provider::Storage.new("config", sdk: @sdk, project_id: "staging", separator: "_")
        assert {
          provider.bucket == "staging_config"
        }
      end
    end
  end

  describe "#initialize" do
    describe "SDK options" do
      it "forwards them without the provider-only options" do
        options = {project_id: "staging", retries: 0, credentials: :test_credentials}
        Bindan::Provider::Storage.new("config", sdk: @sdk, raise_error: true, separator: "_", **options)
        assert {
          @sdk.options == options
        }
      end
    end

    describe "STORAGE_EMULATOR_HOST is set" do
      it "adds a root path when the endpoint path is empty" do
        ENV["STORAGE_EMULATOR_HOST"] = "http://localhost:4443"
        Bindan::Provider::Storage.new("config", sdk: @sdk)
        assert {
          @sdk.options == {endpoint: "http://localhost:4443/"}
        }
      end

      it "preserves an existing endpoint path" do
        ENV["STORAGE_EMULATOR_HOST"] = "http://localhost:4443/storage"
        Bindan::Provider::Storage.new("config", sdk: @sdk)
        assert {
          @sdk.options == {endpoint: "http://localhost:4443/storage"}
        }
      end
    end

    describe "STORAGE_EMULATOR_HOST is not set" do
      it "keeps the explicitly supplied SDK endpoint" do
        Bindan::Provider::Storage.new("config", sdk: @sdk, endpoint: "http://localhost:9999/")
        assert {
          @sdk.options == {endpoint: "http://localhost:9999/"}
        }
      end
    end
  end
end

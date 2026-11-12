require "spec_helper"

class SecretManagerSdkStub
  attr_reader :names

  def initialize
    @names = []
  end

  def new
    yield OpenStruct.new
    self
  end

  def access_secret_version(name:)
    @names << name
    OpenStruct.new(payload: OpenStruct.new(data: ""))
  end
end

describe Bindan::Provider::SecretManager do
  before {
    @sdk = SecretManagerSdkStub.new
    @environment = {
      "GOOGLE_CLOUD_PROJECT" => ENV.delete("GOOGLE_CLOUD_PROJECT"),
      "GCLOUD_PROJECT" => ENV.delete("GCLOUD_PROJECT")
    }
  }

  after {
    @environment.each { |key, value| ENV[key] = value }
  }

  describe "#initialize" do
    describe "project_id is omitted" do
      describe "GOOGLE_CLOUD_PROJECT is set" do
        before {
          ENV["GOOGLE_CLOUD_PROJECT"] = "environment-project"
          ENV["GCLOUD_PROJECT"] = "legacy-project"
        }

        it "uses GOOGLE_CLOUD_PROJECT before GCLOUD_PROJECT" do
          provider = Bindan::Provider::SecretManager.new(sdk: @sdk)
          assert { provider.project_id == "environment-project" }
        end
      end

      describe "only GCLOUD_PROJECT is set" do
        before {
          ENV["GCLOUD_PROJECT"] = "legacy-project"
        }

        it "uses GCLOUD_PROJECT" do
          provider = Bindan::Provider::SecretManager.new(sdk: @sdk)
          assert { provider.project_id == "legacy-project" }
        end
      end
    end

    describe "project_id is supplied" do
      before {
        ENV["GOOGLE_CLOUD_PROJECT"] = "environment-project"
        ENV["GCLOUD_PROJECT"] = "legacy-project"
      }

      it "uses the explicit project instead of the environment" do
        provider = Bindan::Provider::SecretManager.new(project_id: "test-project", sdk: @sdk)
        assert { provider.project_id == "test-project" }
      end
    end
  end

  describe "#[]" do
    before {
      @provider = Bindan::Provider::SecretManager.new(project_id: "test-project", sdk: @sdk)
    }

    it "uses the explicit project and latest version for the secret ID" do
      @provider["api-key"]
      assert {
        @sdk.names == ["projects/test-project/secrets/api-key/versions/latest"]
      }
    end
  end
end

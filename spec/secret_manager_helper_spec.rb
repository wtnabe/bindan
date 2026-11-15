require "spec_helper"
require "minitest/mock"
require "bindan/secret_manager_helper"

describe Bindan::SecretManagerHelper do
  before {
    @config = Google::Cloud::SecretManager::V1::SecretManagerService::Client::Configuration.new
    @environment = %w[GOOGLE_CLOUD_PROJECT GCLOUD_PROJECT].to_h { |key| [key, ENV.delete(key)] }
  }

  after {
    @environment.each { |key, value| ENV[key] = value }
  }

  def build_helper(**options)
    Google::Cloud::SecretManager::V1::SecretManagerService::Client.stub(:new, nil, @config) do
      Bindan::SecretManagerHelper.new(**options)
    end
  end

  describe "#initialize" do
    it "prefers the explicit project to environment variables" do
      ENV["GOOGLE_CLOUD_PROJECT"] = "primary"
      ENV["GCLOUD_PROJECT"] = "legacy"
      helper = build_helper(project_id: "explicit")
      assert { helper.project_id == "explicit" }
    end

    it "prefers GOOGLE_CLOUD_PROJECT to GCLOUD_PROJECT" do
      ENV["GOOGLE_CLOUD_PROJECT"] = "primary"
      ENV["GCLOUD_PROJECT"] = "legacy"
      assert { build_helper.project_id == "primary" }
    end

    it "falls back to GCLOUD_PROJECT" do
      ENV["GCLOUD_PROJECT"] = "legacy"
      assert { build_helper.project_id == "legacy" }
    end

    it "forwards SDK options but disables write retries" do
      @config.rpcs.add_secret_version.retry_policy = {retry_codes: [14]}
      build_helper(endpoint: "localhost:9090", retry_policy: {retry_codes: [14]})
      assert {
        @config.endpoint == "localhost:9090" &&
          @config.retry_policy.nil? && @config.rpcs.add_secret_version.retry_policy.nil?
      }
    end
  end

  describe "#revert" do
    it "rejects latest as a source because revert requires a known-good numerical version" do
      helper = build_helper(project_id: "test-project")
      assert_raises(ArgumentError) { helper.revert("api-key", version: "latest") }
    end
  end
end

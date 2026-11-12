require "integration_helper"

describe Bindan::Provider::SecretManager do
  before {
    @emulator = IntegrationEmulators.secret_manager
    @emulator.clear
    @provider = Bindan::Provider::SecretManager.new(
      project_id: @emulator.project_id,
      endpoint: @emulator.endpoint,
      credentials: :this_channel_is_insecure,
      timeout: 2
    )
  }

  after {
    @emulator.clear
  }

  def create_secret(key)
    @emulator.client.create_secret(
      parent: "projects/#{@emulator.project_id}", secret_id: key,
      secret: {replication: {automatic: {}}}
    ).name
  end

  def add_version(secret, value)
    @emulator.client.add_secret_version(parent: secret, payload: {data: value}).name
  end

  it "reads the latest of multiple created versions through the official SDK" do
    secret = create_secret("api-key")
    add_version(secret, "non-sensitive-old-value")
    add_version(secret, "non-sensitive-new-value")
    assert { @provider["api-key"] == "non-sensitive-new-value" }
  end

  describe "#[]" do
    describe "project_id is omitted" do
      before {
        secret = create_secret("api-key")
        add_version(secret, "non-sensitive-test-value")
        @provider = Bindan::Provider::SecretManager.new(
          endpoint: @emulator.endpoint,
          credentials: :this_channel_is_insecure,
          timeout: 2
        )
      }

      it "reads the secret in the environment project" do
        assert { @provider["api-key"] == "non-sensitive-test-value" }
      end
    end
  end

  describe "when the secret has already been read" do
    before {
      @secret = create_secret("api-key")
      add_version(@secret, "non-sensitive-old-value")
      @initial_value = @provider["api-key"]
    }

    it "returns the initial version's value" do
      assert { @initial_value == "non-sensitive-old-value" }
    end

    describe "when a new version is added" do
      before {
        add_version(@secret, "non-sensitive-new-value")
      }

      it "reads the new version without recreating the provider" do
        assert { @provider["api-key"] == "non-sensitive-new-value" }
      end
    end
  end

  it "preserves binary payload bytes including whitespace" do
    secret = create_secret("binary")
    value = "\x00\xFFnon-sensitive-test-value\n".b
    add_version(secret, value)
    assert { @provider["binary"] == value }
  end

  it "returns an empty string for an empty payload" do
    secret = create_secret("empty")
    add_version(secret, "")
    assert { @provider["empty"] == "" }
  end

  it "propagates NotFoundError for a missing secret" do
    assert_raises(Google::Cloud::NotFoundError) { @provider["missing"] }
  end

  it "propagates NotFoundError for a secret with no versions" do
    create_secret("no-versions")
    assert_raises(Google::Cloud::NotFoundError) { @provider["no-versions"] }
  end

  describe "when secrets have been cleared" do
    before {
      secret = create_secret("api-key")
      add_version(secret, "non-sensitive-old-value")
      @emulator.clear
    }

    it "cannot read the previous secret" do
      assert_raises(Google::Cloud::NotFoundError) { @provider["api-key"] }
    end

    describe "when the same key is recreated" do
      before {
        secret = create_secret("api-key")
        add_version(secret, "non-sensitive-new-value")
      }

      it "returns the new secret's value" do
        assert { @provider["api-key"] == "non-sensitive-new-value" }
      end
    end
  end

  describe "when SDK debug logging is enabled globally" do
    before {
      @previous_logging = ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"]
      secret = create_secret("log-probe")
      add_version(secret, "NON_SENSITIVE_LOG_PROBE")
      ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"] = "all"
      @stdout, @stderr = capture_subprocess_io do
        provider = Bindan::Provider::SecretManager.new(
          project_id: @emulator.project_id,
          endpoint: @emulator.endpoint,
          credentials: :this_channel_is_insecure,
          timeout: 2
        )
        @value = provider["log-probe"]
      end
    }

    after {
      ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"] = @previous_logging
    }

    it "returns the payload" do
      assert { @value == "NON_SENSITIVE_LOG_PROBE" }
    end

    it "does not write to stdout" do
      assert { @stdout.empty? }
    end

    it "does not write to stderr" do
      assert { @stderr.empty? }
    end
  end

  # This describes the pinned emulator's limitation, NOT the provider contract:
  # real GCP latest targets the newest created version, even if it is disabled.
  %i[disable_secret_version destroy_secret_version].each do |operation|
    it "records the emulator latest-enabled divergence after #{operation}" do
      secret = create_secret("api-key")
      add_version(secret, "non-sensitive-old-value")
      newest = add_version(secret, "non-sensitive-new-value")
      @emulator.client.public_send(operation, name: newest)
      assert { @provider["api-key"] == "non-sensitive-old-value" }
    end
  end
end

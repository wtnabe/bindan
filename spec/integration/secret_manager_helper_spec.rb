require "integration_helper"
require "bindan/secret_manager_helper"
require "bindan/secret_update_command"
require "stringio"
require "tempfile"

describe Bindan::SecretManagerHelper do
  before {
    @emulator = IntegrationEmulators.secret_manager
    @emulator.clear
    @helper = build_helper
    @secret = @emulator.client.create_secret(
      parent: "projects/#{@emulator.project_id}", secret_id: "api-key",
      secret: {replication: {automatic: {}}}
    ).name
  }

  after { @emulator.clear }

  def build_helper(project_id: @emulator.project_id)
    Bindan::SecretManagerHelper.new(
      project_id: project_id, endpoint: @emulator.endpoint,
      credentials: :this_channel_is_insecure, timeout: 2
    )
  end

  def read_version(name)
    @emulator.client.access_secret_version(name: name).payload.data
  end

  describe "#update" do
    it "preserves binary bytes and trailing newlines through the official SDK" do
      data = "\x00\xFFnon-sensitive-value\r\n\n".b
      version = @helper.update("api-key", data: data)
      assert { read_version(version.name) == data }
    end

    it "preserves an empty payload through the official SDK" do
      version = @helper.update("api-key", data: "")
      assert { read_version(version.name) == "" }
    end
  end

  describe "#last_version" do
    it "returns nil when the secret has no versions" do
      assert { @helper.last_version("api-key").nil? }
    end

    it "identifies the version added by an update" do
      first = @helper.update("api-key", data: "non-sensitive-value")
      before = @helper.last_version("api-key")
      added = @helper.update("api-key", data: "non-sensitive-value")
      after = @helper.last_version("api-key")
      assert { before.name == first.name && after.name == added.name && before.name != after.name }
    end

    %i[disable_secret_version destroy_secret_version].each do |operation|
      it "returns the last created version even after #{operation}" do
        @helper.update("api-key", data: "non-sensitive-old")
        added = @helper.update("api-key", data: "non-sensitive-new")
        @emulator.client.public_send(operation, name: added.name)
        assert { @helper.last_version("api-key").name == added.name }
      end
    end
  end

  describe "#revert" do
    it "copies the source bytes into a new version" do
      data = "\x00\xFFnon-sensitive-original\n".b
      source = @helper.update("api-key", data: data)
      changed = @helper.update("api-key", data: "non-sensitive-changed")
      restored = @helper.revert("api-key", version: source.name.split("/").last)
      assert {
        restored.name != source.name && restored.name != changed.name && read_version(restored.name) == data
      }
    end
  end

  describe "SDK logging" do
    it "does not output values during update or revert even with global SDK logging enabled" do
      previous = ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"]
      ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"] = "all"
      stdout, stderr = capture_subprocess_io do
        helper = build_helper
        source = helper.update("api-key", data: "NON_SENSITIVE_LOG_PROBE\n")
        helper.revert("api-key", version: source.name.split("/").last)
      end
      assert { stdout.empty? && stderr.empty? }
    ensure
      ENV["GOOGLE_SDK_RUBY_LOGGING_GEMS"] = previous
    end
  end

  describe Bindan::SecretUpdateCommand do
    it "reports an SDK failure without exception details" do
      stdout = StringIO.new
      stderr = StringIO.new
      command = Bindan::SecretUpdateCommand.new(
        helper_factory: ->(**options) { build_helper(**options) },
        stdout: stdout, stderr: stderr
      )
      status = command.run([
        "--project", @emulator.project_id, "--secret", "missing", "--from-version", "1"
      ])
      assert {
        status == 1 && stdout.string.empty? &&
          stderr.string == "Secret update failed. A version may have been created; check the target before retrying.\n"
      }
    end

    it "adds file bytes and reverts through the command, printing only created names" do
      stdout = StringIO.new
      stderr = StringIO.new
      command = Bindan::SecretUpdateCommand.new(
        helper_factory: ->(**options) { build_helper(**options) },
        stdout: stdout, stderr: stderr
      )
      Tempfile.create("bindan-secret-integration") do |file|
        data = "\x00\xFFNON_SENSITIVE_CLI_PROBE\r\n\n".b
        file.binmode
        file.write(data)
        file.flush
        arguments = ["--project", @emulator.project_id, "--secret", "api-key"]
        update_status = command.run(arguments + ["--file", file.path])
        source = stdout.string.chomp
        @helper.update("api-key", data: "NON_SENSITIVE_CHANGED")
        stdout.truncate(0)
        stdout.rewind
        revert_status = command.run(arguments + ["--from-version", source.split("/").last])
        created = stdout.string.chomp
        assert {
          update_status == 0 && revert_status == 0 && stderr.string.empty? &&
            created != source && stdout.string == "#{created}\n" &&
            read_version(source) == data && read_version(created) == data
        }
      end
    end
  end
end

require "spec_helper"
require "stringio"
require "bindan/secret_update_command"

describe Bindan::SecretUpdateCommand do
  describe ".parse" do
    it "parses file input and an explicit project" do
      options = Bindan::SecretUpdateCommand.parse(%w[--project test-project --secret api-key --file key.bin])
      assert { options == {project_id: "test-project", secret: "api-key", file: "key.bin"} }
    end

    it "parses a source version without an explicit project" do
      options = Bindan::SecretUpdateCommand.parse(%w[--secret api-key --from-version 1])
      assert { options == {secret: "api-key", version: "1"} }
    end

    it "accepts help without update arguments" do
      assert { Bindan::SecretUpdateCommand.parse(["--help"]) == {help: true} }
    end

    it "requires a secret" do
      assert_raises(OptionParser::InvalidArgument) {
        Bindan::SecretUpdateCommand.parse(%w[--file key.bin])
      }
    end

    it "requires an input source" do
      assert_raises(OptionParser::InvalidArgument) {
        Bindan::SecretUpdateCommand.parse(%w[--secret api-key])
      }
    end

    it "rejects selecting both input sources" do
      assert_raises(OptionParser::InvalidArgument) {
        Bindan::SecretUpdateCommand.parse(%w[--secret api-key --file key.bin --from-version 1])
      }
    end

    it "rejects positional arguments" do
      assert_raises(OptionParser::InvalidArgument) {
        Bindan::SecretUpdateCommand.parse(%w[--secret api-key --from-version 1 extra])
      }
    end
  end

  describe "#run" do
    before {
      @stdout = StringIO.new
      @stderr = StringIO.new
      @command = Bindan::SecretUpdateCommand.new(
        stdout: @stdout, stderr: @stderr
      )
    }

    it "prints help without creating a client" do
      status = @command.run(["--help"])
      assert { status == 0 && @stdout.string == Bindan::SecretUpdateCommand::USAGE && @stderr.string.empty? }
    end

    it "reports argument errors without echoing their values" do
      status = @command.run(%w[--unknown SECRET_PROBE])
      assert { status == 2 && @stdout.string.empty? && @stderr.string == Bindan::SecretUpdateCommand::USAGE }
    end
  end
end

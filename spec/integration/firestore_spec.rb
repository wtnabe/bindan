require "integration_helper"

describe Bindan::Provider::Firestore do
  before {
    @emulator = Bindan::Emulator::FirestoreController.start
    @emulator.wait_available
  }

  after {
    @emulator.stop(with_message: false)
  }

  describe "#[]" do
    describe "document exists" do
      it "returns the document data" do
        provider = Bindan::Provider::Firestore.new("config")
        provider._prepare({"config/test" => {"foo" => "bar"}})
        assert {
          provider["test"].to_h == {foo: "bar"}
        }
      end
    end

    describe "document does not exist" do
      it "returns nil by default" do
        provider = Bindan::Provider::Firestore.new("config")
        assert {
          provider["foo"].nil?
        }
      end

      it "raises ColOrDocNotExist when raise_error is enabled" do
        provider = Bindan::Provider::Firestore.new("config", raise_error: true)
        assert_raises Bindan::Provider::Firestore::ColOrDocNotExist do
          provider["foo"]
        end
      end
    end
  end
end

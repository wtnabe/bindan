require "spec_helper"

describe Bindan::Provider::Firestore do
  before {
    @emulator = Bindan::Emulator::FirestoreController.start
    @emulator.wait_available
  }

  after {
    @emulator.stop(with_message: false)
  }

  describe "initialize without collection" do
    before {
      @provider = Bindan::Provider::Firestore.new
    }

    describe "document exists" do
      before {
        @provider._prepare({"config/test" => {"foo" => "bar"}})
      }

      it {
        assert {
          @provider["config/test"].to_h == {foo: "bar"}
        }
      }
    end

    it "not exist" do
      assert {
        @provider["config/foo"].nil?
      }
    end
  end

  describe "initialize with collection" do
    before {
      @provider = Bindan::Provider::Firestore.new("config")
    }

    describe "document exists" do
      before {
        @provider._prepare({"config/test" => {"foo" => "bar"}})
      }

      it {
        assert {
          @provider["test"].to_h == {foo: "bar"}
        }
      }
    end

    it "not exist" do
      assert {
        @provider["foo"].nil?
      }
    end
  end

  describe "raise_error" do
    before {
      @provider = Bindan::Provider::Firestore.new("config", raise_error: true)
    }

    it "" do
      assert_raises Bindan::Provider::Firestore::ColOrDocNotExist do
        @provider["foo"]
      end
    end
  end
end

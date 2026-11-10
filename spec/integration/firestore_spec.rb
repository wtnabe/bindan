require "integration_helper"

describe Bindan::Provider::Firestore do
  before {
    IntegrationEmulators.firestore.clear
  }

  describe "#[]" do
    describe "document exists" do
      it "returns the document data" do
        provider = Bindan::Provider::Firestore.new("config", project_id: IntegrationEmulators::FIRESTORE_PROJECT_ID)
        provider._prepare({"config/test" => {"foo" => "bar"}})
        assert {
          provider["test"].to_h == {foo: "bar"}
        }
      end
    end

    describe "document does not exist" do
      it "returns nil by default" do
        provider = Bindan::Provider::Firestore.new("config", project_id: IntegrationEmulators::FIRESTORE_PROJECT_ID)
        assert {
          provider["test"].nil?
        }
      end

      it "raises ColOrDocNotExist when raise_error is enabled" do
        provider = Bindan::Provider::Firestore.new("config", project_id: IntegrationEmulators::FIRESTORE_PROJECT_ID, raise_error: true)
        assert_raises Bindan::Provider::Firestore::ColOrDocNotExist do
          provider["test"]
        end
      end
    end

    it "clears the previous value before reusing the same key" do
      provider = Bindan::Provider::Firestore.new("config", project_id: IntegrationEmulators::FIRESTORE_PROJECT_ID)
      provider._prepare({"config/test" => {"foo" => "old"}})
      assert { provider["test"] == {foo: "old"} }

      IntegrationEmulators.firestore.clear
      assert { provider["test"].nil? }
      provider._prepare({"config/test" => {"foo" => "new"}})
      assert { provider["test"] == {foo: "new"} }
    end
  end
end

require "spec_helper"

describe Bindan::Provider::Storage do
  before {
    @provider = Bindan::Provider::Storage.new("config")
  }

  describe "object exists" do
    it {
      assert {
        @provider["rack_env"] == "development"
      }
    }
  end

  describe "object not exist" do
    describe "describe" do
      it "return nil" do
        assert {
          @provider["foo"].nil?
        }
      end
    end

    describe "rails_error option" do
      before {
        @provider = Bindan::Provider::Storage.new("config", raise_error: true)
      }

      it "FileNotExist Error" do
        assert_raises Bindan::Provider::Storage::FileNotExist do
          @provider["foo"]
        end
      end
    end
  end
end

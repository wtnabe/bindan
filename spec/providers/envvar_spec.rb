require "spec_helper"

describe Bindan::Provider::Envvar do
  describe "key exists" do
    before {
      @provider = Bindan::Provider::Envvar.new({"foo" => 1})
    }

    it "return value" do
      assert {
        @provider["foo"] == 1
      }
    end
  end

  describe "key does not exist" do
    describe "default" do
      before {
        @provider = Bindan::Provider::Envvar.new({})
      }

      it "returns nil" do
        assert {
          @provider["foo"].nil?
        }
      end
    end

    describe "raise_error option enabled" do
      before {
        @provider = Bindan::Provider::Envvar.new({}, {raise_error: true})
      }

      it "raise KeyError" do
        assert_raises KeyError do
          @provider["foo"]
        end
      end
    end
  end
end

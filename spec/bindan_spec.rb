# frozen_string_literal: true

require "spec_helper"

class FakeEnvvar
  def [](key = nil)
    "bar" if key == "foo"
  end
end

class TestingConfigClass
  extend Bindan
end

describe Bindan do
  it "has a version number" do
    assert {
      !Bindan::VERSION.nil?
    }
  end

  describe ".configure" do
    it "fake_envvar" do
      config = Bindan.configure(providers: {env: FakeEnvvar.new}) do |c, pr|
        c.foo = pr.env["foo"]
      end

      assert {
        config.foo == "bar"
      }
    end

    it "provider returns nil, then `or assign'" do
      config = Bindan.configure(providers: {env: FakeEnvvar.new}) do |c, pr|
        c.bar = pr.env["bar"] || "baz"
      end

      assert {
        config.bar == "baz"
      }
    end

    describe "extended class" do
      it {
        TestingConfigClass.configure(providers: {env: FakeEnvvar.new}) do |c, pr|
          c.foo = pr.env["foo"]
        end

        p TestingConfigClass.config

        assert {
          TestingConfigClass.config.foo == "bar"
        }
      }
    end
  end
end

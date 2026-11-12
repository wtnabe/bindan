require "minitest/autorun"
require "minitest-power_assert"
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "bindan"

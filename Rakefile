# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create(:spec) do |t|
  t.libs << "spec"
  t.test_globs = "spec/**/*_spec.rb"
  t.warning = false
end

require "standard/rake"

task default: %i[spec standard]

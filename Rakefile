# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create(:spec) do |t|
  t.libs << "spec"
  t.test_globs = Dir.glob("spec/**/*_spec.rb").reject { |path| path.start_with?("spec/integration/") }
  t.warning = false
end

Minitest::TestTask.create("spec:integration") do |t|
  t.libs << "spec"
  t.test_globs = "spec/integration/**/*_spec.rb"
  t.warning = false
end

require "standard/rake"

task default: %i[spec standard]

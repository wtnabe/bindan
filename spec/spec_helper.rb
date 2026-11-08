require "minitest/autorun"
require "minitest-power_assert"
require "minitest/reporters"
require "fileutils"

Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Load the gem's code.
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "bindan"

# Set up environment variables for client libraries to connect to emulators.
ENV["GCP_PROJECT"] = "bindan-test"
ENV["GOOGLE_CLOUD_PROJECT"] = "bindan-test"
ENV["GCLOUD_PROJECT"] = "bindan-test"
ENV["STORAGE_EMULATOR_HOST"] = "http://localhost:4443"
ENV["FIRESTORE_EMULATOR_HOST"] = "localhost:8080"

config_folder = File.join(__dir__, "tmp/storage/-config")
FileUtils.mkdir_p(config_folder)
FileUtils.cp(File.join(__dir__, "support/storage/rack_env"), config_folder)

#
# setup emulators
#
load File.join(__dir__, "../bin/emulator")

emulators = Bindan::Emulator.start(
  {
    "GcsServerController" => {
      folder: File.join(__dir__, "tmp/storage")
    },
    "FirestoreController" => {
      export: File.join(__dir__, "tmp/firestore")
    }
  },
  skip: ENV["CI"] ? ["GcsServerController"] : []
)

Minitest.after_run {
  emulators.map { |c| c.stop }
}

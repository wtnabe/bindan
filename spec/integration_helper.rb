require "spec_helper"
require "fileutils"

# Set up environment variables for client libraries to connect to emulators.
ENV["GCP_PROJECT"] = "bindan-test"
ENV["GOOGLE_CLOUD_PROJECT"] = "bindan-test"
ENV["GCLOUD_PROJECT"] = "bindan-test"
ENV["STORAGE_EMULATOR_HOST"] = "http://localhost:4443"
ENV["FIRESTORE_EMULATOR_HOST"] = "localhost:8080"

if ENV["CI"]
  Google::Cloud.configure.storage.credentials = Google::Auth::Credentials.new(
    Signet::OAuth2::Client.new(access_token: "bindan-test-token"),
    project_id: "bindan-test"
  )
end

config_folder = File.join(__dir__, "tmp/storage/-config")
FileUtils.mkdir_p(config_folder)
FileUtils.cp_r(File.join(__dir__, "support/storage/."), config_folder)

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

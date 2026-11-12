require "spec_helper"
require_relative "../lib/bindan/emulators/gcs_server_controller"
require_relative "../lib/bindan/emulators/firestore_controller"

# Set up environment variables for client libraries to connect to emulators.
ENV["GCP_PROJECT"] = "bindan-test"
ENV["GOOGLE_CLOUD_PROJECT"] = "bindan-test"
ENV["GCLOUD_PROJECT"] = "bindan-test"
ENV["STORAGE_EMULATOR_HOST"] = "http://localhost:4443"
ENV["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:8080"

module IntegrationEmulators
  FIRESTORE_PROJECT_ID = "bindan-test"

  class << self
    attr_accessor :firestore
  end
end

if ENV["CI"]
  Google::Cloud.configure.storage.credentials = Google::Auth::Credentials.new(
    Signet::OAuth2::Client.new(access_token: "bindan-test-token"),
    project_id: "bindan-test"
  )
end

#
# Wait for externally managed emulators; tests never start or stop containers.
#
Bindan::Emulator::GcsServerController.new.wait_available
IntegrationEmulators.firestore = Bindan::Emulator::FirestoreController.new(
  project_id: IntegrationEmulators::FIRESTORE_PROJECT_ID
)
IntegrationEmulators.firestore.wait_available

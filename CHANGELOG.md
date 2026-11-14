## [Unreleased]

## [0.2.0] - 2026-11-13

### Added

- Add `Bindan::Provider::SecretManager` to read configuration from Google Cloud Secret Manager.

## [0.1.2] - 2026-11-12

### Changed

- Separate Docker-free unit tests from emulator-backed integration tests.
- Manage GCS and Firestore emulators with Docker Compose. CI starts and stops the services; local integration tests use externally started services.
- Clear Firestore test data between cases instead of restarting the emulator for each test.
- Extract Firestore document path resolution without changing lookup behavior.

### Fixed

- Correct the multiple-Provider README example and clarify Storage bucket names and Firestore collection paths.
- Restore Cloud Storage integration coverage in CI and constrain development dependencies for Ruby 3.0 compatibility.

### Development compatibility

- Remove `bin/emulator` and controller startup/shutdown APIs. Use `docker compose up` / `down` instead; host Java and Google Cloud CLI are no longer required. Firestore import/export is no longer supported by the development tooling.

## [0.1.1] - 2025-08-07

- add Class-extend use

## [0.1.0] - 2025-08-03

- Initial release

## [0.0.0] - 2025-07-12

- start project

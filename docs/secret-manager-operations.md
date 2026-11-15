# Secret Manager operations from Cloud Shell

## Update and revert

Bindan's Secret Manager Provider reads `latest`. The update sequence is:

1. Add a new version with the CLI and record the returned version name.
2. Inspect the last created version without filtering by state or resolving an alias.
3. Follow the [configuration rollout guide](configuration-rollout.md) to replace
   the execution units holding Bindan's previous configuration.

For credentials, enable the new credential first and revoke the old one only
after verifying the application rollout. Serialize updates to a secret and
coordinate them with application deployments.

Updating multiple secrets is not a single transaction. If an update fails partway
through, earlier updates remain in effect; neither the CLI nor the Helper rolls
them back automatically. An application starting during the updates can also
load a mixture of old and new values. Plan for these combinations and partial
failures, recording the known-good version of each secret before making changes.

Revert also means adding a version: copy a known-good numerical version into a
new one, then repeat version checks and application rollout. Disabling or
destroying the newest version does **not** revert it. GCP's `latest` selects the
newest created version and fails if it is disabled or destroyed; the emulator
may return an older enabled version instead.

The CLI does not replace instances, move traffic, or guarantee convergence of
`latest`. Start with a non-sensitive secret in a non-production environment.

## 1. Prepare Cloud Shell

Cloud Shell includes Ruby and gcloud, not Bindan or the Secret Manager Ruby SDK.
Include `bindan` and `google-cloud-secret_manager` in your Gemfile, then install
the dependencies:

```bash
bundle install
bundle exec bindan-secret-update --help
```

Authorize the session when Cloud Shell prompts. Normally no
`gcloud auth application-default login` is needed in Cloud Shell; the Ruby SDK
uses [Application Default Credentials](https://cloud.google.com/docs/authentication/set-up-adc-local-dev-environment#local-user-cred).
Check for credential overrides such as `GOOGLE_APPLICATION_CREDENTIALS` or a local
ADC file: the SDK and gcloud can otherwise use different identities. Do not print
tokens or credential files to diagnose access problems.

Updating requires `secretmanager.versions.add`; reverting also requires
`secretmanager.versions.access` to read the source. Inspecting the last created
version requires `secretmanager.versions.list`. The application's identity can
remain read-only for secrets.

```bash
set +x
umask 077
export CLOUDSDK_CORE_LOG_HTTP=false CLOUDSDK_CORE_VERBOSITY=error
PROJECT_ID="my-project"
SECRET_ID="api-key"
gcloud auth list --filter=status:ACTIVE --format='value(account)'
gcloud config get-value project
```

Use explicit project flags below to avoid depending on gcloud's active project.
Without `--project`, Bindan uses `GOOGLE_CLOUD_PROJECT`, then `GCLOUD_PROJECT`.
Cloud Shell initially sets `GOOGLE_CLOUD_PROJECT` from the console's active
project, but changing gcloud's configuration does not set Bindan's environment.

Prepare a protected file outside the checkout containing the exact new bytes.
Do not embed the value in a shell command, history, source control, or build
configuration. Avoid `echo`, which can change newlines. Cloud Shell's home
directory persists between sessions; remove plaintext files when no longer
needed, or use an appropriate ephemeral location. Removal is not secure erasure.

## 2. Update or revert

Record the known-good **numerical** version before making a change. For an update:

```bash
created="$(bundle exec bindan-secret-update \
  --project "$PROJECT_ID" --secret "$SECRET_ID" --file /path/to/api-key.bin)"
```

For a revert, use the same command with a source version instead of a file:

```bash
SOURCE_VERSION="1" # Replace with the recorded known-good version.
created="$(bundle exec bindan-secret-update \
  --project "$PROJECT_ID" --secret "$SECRET_ID" --from-version "$SOURCE_VERSION")"
```

Run only the chosen form and check its exit status before continuing. Both
preserve the input bytes, suppress SDK payload logging, and print only the
created version name on success. Exit status is `0` for success, `2` for argument
errors, and `1` for operational failures. Writes are not automatically retried.
**A failed command may still have created a version.** Check the target and
whether the intended value was added before retrying; do not blindly rerun it.

## 3. Inspect the last created version

The CLI succeeds when the SDK returns the newly created version. It does not
read back and compare secret contents. To inspect the last created version,
list all versions in creation order without filtering by state:

```bash
gcloud secrets versions list "$SECRET_ID" --project "$PROJECT_ID" \
  --sort-by='~createTime' --limit=1 --format='value(name)'
```

Compare this name with the recorded `created` name. Disabled and destroyed versions
are included: the last created version is not necessarily an enabled or known-good
version. Do not use `latest` as a substitute for this lookup, because its behavior
differs between GCP and the emulator when versions are disabled or destroyed.

Listing is [eventually consistent](https://cloud.google.com/secret-manager/docs/access-secret-version#resource_consistency).
If the new version is not visible yet, wait and repeat the lookup, not the update.
The update's result identifies the version it created even while listing lags.
A match does not guarantee that all application reads have converged; allow for
propagation and check application health during rollout.

## Next: reflect the value into the application

Continue with [Reflecting configuration changes in running applications](configuration-rollout.md)
to replace execution units and let Bindan acquire the updated values.
Keep the `latest` lookup unchanged; do not pin a numerical version in the application
to make this change. Follow the same version checks and rollout steps after a revert.

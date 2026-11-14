# Secret Manager operations

## Update and revert: what matters

- **Update by adding a new version.** This provider reads `latest`, which selects
  the newest created version, not the newest enabled one.
- **Reverting requires another update.** Record the known-good version before
  making a change. To restore its value, add that value as a new version.
  Disabling or destroying the newest version does not restore the previous one:
  GCP's `latest` still selects the newest created version and reading it fails.
  The emulator may return an older enabled version instead; GCP does not.
- **Do not expose or accidentally alter the value while updating or reverting.**
  Logs and shell history can retain secrets; added or removed newlines can change
  their meaning. If an update fails or times out, check whether it created a
  version before retrying.

## Manual command examples

These examples use Bash and `gcloud`, including Cloud Shell. They modify an
existing secret; check the account and target before running them, and serialize
updates to the same secret. The operator needs permissions to
access/add versions and read version metadata, separate from the application's
read-only access. Use non-sensitive test data before production use.

```bash
set +x
export CLOUDSDK_CORE_LOG_HTTP=false CLOUDSDK_CORE_VERBOSITY=error
PROJECT_ID="my-project"
SECRET_ID="api-key"
gcloud auth list --filter=status:ACTIVE --format='value(account)'
```

### Update

Prepare a protected file with the exact desired bytes, then add a version.
Avoid `echo` or embedding secrets in shell commands/history. Record the returned
version name and the previous known-good version number.

```bash
gcloud secrets versions add "$SECRET_ID" --project="$PROJECT_ID" \
  --data-file="./api-key.bin" --format='value(name)'
```

### Revert

Copy a known-good numeric version into a new version, then verify its bytes.

```bash
(
  set -euo pipefail
  umask 077
  SOURCE_VERSION="1" # Replace with the known-good version number.
  workdir="$(mktemp -d)"
  trap 'rm -rf -- "$workdir"' EXIT

  gcloud secrets versions access "$SOURCE_VERSION" \
    --secret="$SECRET_ID" --project="$PROJECT_ID" --out-file="$workdir/payload"
  created="$(gcloud secrets versions add "$SECRET_ID" \
    --project="$PROJECT_ID" --data-file="$workdir/payload" --format='value(name)')"
  [[ "$created" =~ /versions/[0-9]+$ ]] || exit 1
  gcloud secrets versions access "${created##*/}" \
    --secret="$SECRET_ID" --project="$PROJECT_ID" --out-file="$workdir/check"
  cmp -s "$workdir/payload" "$workdir/check"
  printf 'Created and verified: %s\n' "$created"
)
```

`--out-file` preserves raw bytes, including trailing newlines. Temporary files
contain plaintext; use a protected environment. Cleanup is not secure erasure.

If the command fails or verification reports a mismatch, check which version was
created and whether its bytes match the intended value before retrying. Do not
assume a failed command means no version was added.

See [version access](https://cloud.google.com/sdk/gcloud/reference/secrets/versions/access)
and [version addition](https://cloud.google.com/sdk/gcloud/reference/secrets/versions/add).

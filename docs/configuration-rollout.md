# Reflecting configuration changes in running applications

## Current limitation and rollout approach

The current Bindan implementation evaluates the configuration block when
`configure` runs and retains the resolved values. Subsequent `config` calls return
that configuration without reading the Providers again. Changing a value at its source does not change
the configuration already held by a running application.

Given this current limitation, this guide reflects changes by completely replacing
the execution units that hold the old configuration, such as instances or containers.
The new units run the application's configuration setup and acquire the updated values. Changing
traffic routing alone does not cause an existing unit to reread configuration.

## Rollout sequence

1. Update the configuration source and verify the values the application will
   read. Follow that source's update and consistency requirements before proceeding;
   source-specific operations are outside this guide.
2. Replace every execution unit that can hold the old configuration, keeping
   enough capacity available to serve requests.
3. Verify that the new units work with the updated configuration and that old
   units no longer handle requests.

New and old configurations can coexist from the moment the source changes:
the platform may start new units independently of this procedure. Keep the
application compatible with both configurations during the transition. Coordinate
the rollout with other configuration changes and application deployments.

## Replace execution units

The examples use Cloud Shell and gcloud. Authorize the session when prompted and
check the account and target project. Instance replacement and revision deployment
require the hosting service's permissions, separately from source read/write access.
These operations affect capacity, running requests, and potentially cost. Start
in a non-production environment and use the application's normal health checks.

```bash
PROJECT_ID="my-project"
```

For external-source changes, reuse the deployed application code or image rather
than rebuilding it. For deployment-supplied values such as environment variables,
update the deployment definition first; replacing units with the unchanged
definition would supply the same values. Choose the hosting service below.

### App Engine Standard

After the source is updated and ready to read, record the UTC cutoff time. Units
started before this point may retain the old configuration and must be replaced:

```bash
REPLACE_BEFORE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

For each service and version that can receive requests, list instances and
review their `id` and `startTime` against `REPLACE_BEFORE`:

```bash
APP_SERVICE="default"
APP_VERSION="my-version"
gcloud app instances list --project "$PROJECT_ID" \
  --service "$APP_SERVICE" --version "$APP_VERSION" --format=json
```

Stop instances started before the cutoff **one at a time**, checking replacement
capacity and application health between operations. App Engine starts instances
according to its scaling configuration and demand; stopping one does not promise
an immediately running replacement. Do not delete all instances at once.

```bash
INSTANCE_ID="replace-with-reviewed-instance-id"
gcloud app instances delete "$INSTANCE_ID" --project "$PROJECT_ID" \
  --service "$APP_SERVICE" --version "$APP_VERSION"
```

List again until no pre-cutoff instances remain for all relevant services and
versions. Include versions reachable through direct version URLs, not only the
default traffic allocation. Check errors and successful use of the updated
configuration without logging sensitive values. Instance age identifies the
replacement targets; it does not prove which values the application loaded.

See [instance deletion](https://cloud.google.com/sdk/gcloud/reference/app/instances/delete)
and [instance fields](https://cloud.google.com/appengine/docs/admin-api/reference/rest/v1/apps.services.versions.instances#Instance).

### Cloud Run

Create a new revision of the same image with a changed, non-sensitive generation
marker. The marker only forces a fresh revision; Bindan does not interpret it.
First review the current traffic, serving revision, and its image digest:

```bash
RUN_SERVICE="my-service"
REGION="asia-northeast1"
gcloud run services describe "$RUN_SERVICE" --project "$PROJECT_ID" \
  --region "$REGION" --format='yaml(status.traffic)'
SERVING_REVISION="replace-with-reviewed-serving-revision"
gcloud run revisions describe "$SERVING_REVISION" --project "$PROJECT_ID" \
  --region "$REGION" --format='value(status.imageDigest)'
```

The example below assumes a single-container service, one serving revision, and
a service template matching that revision's intended configuration. If there are
pending configuration changes, sidecars, or an existing traffic split, adapt the
normal deployment procedure instead of overwriting it with this example. Do not
run concurrently with other deployments. Use the reviewed full image reference
with `@sha256:...`, not a mutable tag, and keep all other settings unchanged.

```bash
IMAGE="replace-with-current-image-reference@sha256:..."
GENERATION="cfg-$(date -u +%Y%m%d%H%M%S)"
NEW_REVISION="$RUN_SERVICE-$GENERATION"
gcloud run deploy "$RUN_SERVICE" --project "$PROJECT_ID" --region "$REGION" \
  --image "$IMAGE" --revision-suffix "$GENERATION" \
  --update-env-vars "BINDAN_CONFIG_GENERATION=$GENERATION" \
  --no-traffic --tag "$GENERATION"
```

Choose a unique generation that keeps the full revision name within Cloud Run's
length limit. Verify the deployment succeeded and test the new revision through
its tagged URL using the service's normal authentication. Check that the
application actually works with the new configuration, not just that it starts.
Then move a small proportion of traffic and monitor it before completing:

```bash
gcloud run services update-traffic "$RUN_SERVICE" \
  --project "$PROJECT_ID" --region "$REGION" \
  --to-revisions "$SERVING_REVISION=95,$NEW_REVISION=5"
# After verifying health, move the remaining traffic.
gcloud run services update-traffic "$RUN_SERVICE" \
  --project "$PROJECT_ID" --region "$REGION" --to-revisions "$NEW_REVISION=100"
```

Confirm the resulting traffic allocation and allow in-flight requests to finish.
Review old tagged URLs and minimum-instance settings too: zero main-service
traffic does not mean an old revision cannot still run or receive direct requests.
See [Cloud Run traffic migration and required roles](https://cloud.google.com/run/docs/rollouts-rollbacks-traffic-migration).

## Verify completion

Confirm that all request-serving execution units use the updated configuration,
including units reachable through direct version or tagged URLs. Monitor errors
and normal application operations that depend on the changed settings; a successful
restart or deployment alone is not sufficient. Do not log sensitive configuration
values while checking them.

If a new unit loads an unexpected value, check the source and the application's
read path before replacing more units. Correct the cause and repeat the replacement
as needed. Retire old values only after confirming that no request-serving units
still depend on them.

## Revert if needed

Restore the known-good values using the source's rollback procedure, verify what
the application will read, and repeat the execution-unit replacement and completion
checks. Restoring the source alone does not change values already held by Bindan.

For Cloud Run, create another fresh revision with a new generation marker. Merely
sending traffic to an old revision does not reliably restore externally loaded
configuration: retained instances may have cached values and newly started ones
read the current source. Verify application behavior and replacement completion,
not only that the source update or deployment command succeeded.

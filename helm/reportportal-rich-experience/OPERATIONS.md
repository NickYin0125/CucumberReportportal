# Video Storage And Gateway Operations

## Managed Storage Contract

Only use a dedicated automation-video bucket. The reconciliation Job owns its
whole anonymous policy and lifecycle. Save existing policy/lifecycle before an
upgrade if you need an audit record; do not restore legacy anonymous read/write
policy as an application rollback. Anonymous object reads are the intended
internal-network behavior; application authentication does not authenticate a
direct video URL. Keep authenticated upload/admin access restricted.

Default settings: 30-day expiry for current/noncurrent objects,
stable rule ID `rp-automation-video-retention`, 4 GiB bucket
hard quota. `mc ilm rule import` prevents duplicate-rule accumulation, but replaces
other lifecycle rules on this dedicated bucket. Expiry runs asynchronously.
No promise is made that ILM alone prevents disk exhaustion.

Fresh-install defaults explicitly request an 8 GiB MinIO PVC and reserve half of
its nominal capacity outside the video quota. This is a reserve, not a quota for
RP's other buckets: those buckets can still exhaust storage. Before any existing
or external deployment, inspect actual PVC capacity, total used bytes across all
buckets, available backing-filesystem space and the storage class's enforcement.
Reject the upgrade if the video quota cannot fit after accounting for other data
and an operating reserve; lower `videoBucket.quota.size` instead. Do not silently
resize an existing PVC. Changes to `reportportal.minio.persistence.size` require
an independent, approved volume-expansion/migration plan and a restore check.

The pinned community MinIO server does **not** persist the bucket-level
`AbortIncompleteMultipartUpload` lifecycle field. Its exact
[2025-07-23 rule definition](https://github.com/minio/minio/blob/RELEASE.2025-07-23T15-54-02Z/internal/bucket/lifecycle/rule.go)
and the local readback agree; do not mistake a successful import for support.
Check the server-wide `api` stale-upload cleanup settings through your admin
client, monitor incomplete-upload bytes, and choose a cleanup age longer than
your longest legitimate upload. Do not apply current AIStor documentation's
capability claims to this older community image. The wrapper does not change
server-wide cleanup settings or automatically abort active uploads.

With an already configured authenticated `mc` alias, routine readback is:

```sh
mc anonymous get-json myminio/automation-videos
mc ilm rule export myminio/automation-videos
mc quota info --json myminio/automation-videos
mc du --json myminio/automation-videos
mc admin config get myminio api
mc ls myminio/automation-videos --incomplete --recursive
```

For abandoned uploads, first review `mc ls` output and the agreed maximum upload
age. An authorized operator may then use `mc rm --incomplete --recursive
--older-than 7d --force myminio/automation-videos`; this permanently aborts eligible
uploads and is not run automatically by the Chart. Never remove MinIO internal
multipart directories directly.

## Initialization And Routine Checks

```sh
kubectl get jobs,pods -n reportportal
kubectl logs -n reportportal job/reportportal-video-bucket-init
kubectl get pvc -n reportportal
kubectl get events -n reportportal --sort-by=.lastTimestamp
```

Alert on a failed or timed-out reconciliation Job. A completed Job proves configured
operations returned success; separately read back bucket policy, retention and
quota with your authenticated MinIO admin client. Check that anonymous access has
only `s3:GetObject`, no listing/write/delete grants, and that the quota fits current
PVC capacity. Repeated upgrades must retain one managed lifecycle rule, not add a
new random ID. Do not expose credentials in shell history or pasted diagnostics.

Configure your monitoring platform for PVC usage at 70% (warning) and 85% (critical),
disk-pressure/node conditions, quota utilization, Job failures, storage/API request
errors and backup freshness. Reserve capacity for RP's non-video attachments,
database, OpenSearch and replicas separately. These are proposed starting
thresholds, not installed Prometheus alerts or a tested capacity/HA specification.

When the video quota is reached, expect upload failure and a degraded SDK receipt;
business execution must preserve its original outcome. Inspect delivery receipts,
not merely a successful Cucumber exit. Increasing the quota without increasing
physical capacity is not a remediation. RP's own project retention may differ:
expired video URLs in old reports are expected after the configured retention.

## Revocation And Retirement

For an existing deployment, apply `videoBucket.makePublic=false` to revoke anonymous
access while retaining the route, or `videoBucket.enabled=false` to remove the route
and reconcile the existing bucket to private access. Leave `revokeOnDisable=true`.
Wait for the Job, read back no anonymous grants and verify 403 through any remaining
MinIO path. Authenticated HEAD should still show the original object length/hash.
An absent bucket is a safe no-op; an unreachable bucket is NOT proof of revocation.

Do this **before** uninstalling the release. Helm uninstall alone does not revoke
an external bucket's policy. `revokeOnDisable=false` deliberately disables policy
management and requires a separate operator revocation step. Disabling retention
or quota management does not remove previously applied settings; removal must be
an explicit, audited operator decision rather than accidental storage exposure.

## Backup And Recovery

Define backup frequency/RPO/RTO for the actual deployment. Back up RP metadata
(PostgreSQL), all attachment buckets and required deployment configuration through
your approved storage/secret tooling; keep secret values outside Git and evidence
logs. A database-only backup does not restore external video objects. Record which
recordings may have expired under ILM and coordinate backup retention accordingly.

Perform restore drills into an isolated namespace/instance. Verify Launch/item
topology, representative log/attachment SHA-256, source ownership and video playback.
Only then claim recovery readiness. This task configures guards and provides a
runbook; it does not claim production HA, backup-service installation, a real
Huawei restore rehearsal, or migration of the preserved historical RP environment.

## Controller Migration

The wrapper defaults to standard Prefix routes using class `traefik`. The local
controller can be installed separately with Helm >=3.18.4:

```sh
helm repo add traefik https://traefik.github.io/charts
helm repo update traefik
helm upgrade --install rp-traefik traefik/traefik --version 41.7.1 \
  -n rp-ingress --create-namespace \
  -f ./helm/reportportal-rich-experience/values-traefik-controller-local.yaml \
  --wait --timeout 5m
```

That profile initially exposes 18080 for parallel validation, not a production
listener. Verify RP and video paths, then deliberately move the listener/DNS after
recording rollback settings. The Chart does not mutate your shared controller.
For Huawei private cloud, follow [the platform checklist](HUAWEI_PRIVATE_CLOUD.md).

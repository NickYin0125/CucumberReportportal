# ReportPortal Rich Experience Helm Chart

## Version Contract

Wrapper chart **1.3.0** pins official chart **26.8.12**, ReportPortal **26.0.5**.
`appVersion` identifies the ReportPortal server, not the independent Ruby SDK version.
The dependency archive and lock file are included in the packaged chart.
The wrapper also initializes RabbitMQ's default vhost as `analyzer`, matching
ReportPortal's `msgbroker.vhost`, so a fresh broker grants its bootstrap user the
required permissions. If you customize that vhost, update both settings. This
bootstrap setting does not repair permissions on an already initialized broker;
verify its user/vhost permissions explicitly during migration.

| Component | Pinned image version |
| --- | --- |
| API / migrations | 5.15.4 |
| UI | 5.15.5 |
| Authorization / index | 5.15.1 |
| Jobs | 5.15.2 |
| Analyzer | 5.15.5 |
| PostgreSQL | 18.4 |
| RabbitMQ | 4.3.4-management |
| OpenSearch | 3.8.0 |

Requires Kubernetes >= 1.26, Helm 3 and a compatible Ingress controller.
The routes now use standard `Prefix` matching, preserve the full S3 bucket path,
and have no NGINX-specific annotations. The default class is `traefik`; the wrapper
does not install or own your shared controller. A separately installed Traefik
41.7.1 / Proxy 3.7.14 is the local acceptance implementation. Use Helm >=3.18.4
for that modern controller chart; old Helm 3.7 cannot render its Go templates.
This is an Ingress solution, not a claimed Gateway API implementation.

## Fresh Installation

Provision an `rp-runtime-auth` Kubernetes Secret in the target namespace using
your secret manager. Do not store its values in Git or pass passwords as command
arguments. It must contain these keys:

| Secret key | Consumer |
| --- | --- |
| `postgresql-password` | ReportPortal and PostgreSQL |
| `rabbitmq-password`, `erlang-cookie` | ReportPortal and RabbitMQ |
| `root-user`, `access-key` | MinIO and ReportPortal; use the same username |
| `root-password`, `secret-key` | MinIO and ReportPortal; use the same password |
| `superadmin-password` | Initial administrator login |

For isolated local acceptance, the preconfigured hostname is `rp-latest.localhost`:

```sh
helm dependency build ./helm/reportportal-rich-experience
helm lint ./helm/reportportal-rich-experience -f ./helm/reportportal-rich-experience/values-local-latest.yaml
helm install reportportal-latest ./helm/reportportal-rich-experience \
  -n reportportal-latest --create-namespace \
  -f ./helm/reportportal-rich-experience/values-local-latest.yaml \
  --wait --wait-for-jobs --timeout 20m
```

Visit `http://rp-latest.localhost/ui/`. Use the same origin for
`RP_ENDPOINT=http://rp-latest.localhost` and
`RP_MINIO_PUBLIC_BASE_URL=http://rp-latest.localhost` (the uploader appends the bucket).
The Ruby uploader additionally needs a reachable authenticated MinIO API endpoint;
the public URL is only for browser reads. Old reports are not imported automatically.

For a production **fresh install**, copy `values-production.example.yaml`, replace
its hostname and TLS Secret, and configure storage classes, capacity, backup/restore,
resource limits, network policies and availability for your cluster:

```sh
helm package ./helm/reportportal-rich-experience -d ./pkg
helm install reportportal ./pkg/reportportal-rich-experience-1.3.0.tgz \
  -n reportportal --create-namespace -f ./production-values.yaml \
  --wait --wait-for-jobs --timeout 20m
```

The production example retains anonymous **object reads only** for internal-network
video playback. Authenticated upload/delete credentials are separate from viewer
access. `makePublic` is the backward-compatible flag name, but it no longer means
MinIO's unsafe `public` preset: the Job replaces the entire old bucket policy with
one `s3:GetObject` grant. HEAD and Range requests still work; anonymous listing,
PUT and DELETE are not granted. Anyone able to reach a known internal object URL
can read it; this is intentionally not user-authenticated media delivery or PII
redaction. Restrict network reachability according to your internal trust boundary.

`makePublic=false` actively replaces the existing policy with no anonymous grants.
`enabled=false` removes the video route and still runs a revocation Job by default;
it never deletes the bucket or recordings. An absent bucket is a safe no-op, but
authorization/network failures fail the Job. Only `revokeOnDisable=false` explicitly
opts out of this reconciliation. Do not uninstall first and expect Helm to revoke
an existing bucket: apply the disabled configuration, wait for the Job, verify
denied anonymous access, then uninstall if necessary.

This chart owns the complete policy and lifecycle on a **dedicated** video bucket.
Do not point it at a shared business-data bucket. Retention imports one stable-ID
rule (30 days by default), including noncurrent versions; it replaces existing
lifecycle rules on that dedicated bucket. The pinned community server does not
persist bucket-level incomplete-upload expiry; see the separate stale-upload
checks in [OPERATIONS.md](OPERATIONS.md).
The default hard quota is 4 GiB on an explicitly provisioned 8 GiB MinIO volume,
reserving half the nominal capacity for RP attachments and overhead. Tune it below
available physical storage and
reserve space for RP database/attachments. Retention is asynchronous, not a disk-
full guarantee. Retention or quota failures fail initialization, rather than only
printing a warning. Setting their `enabled` flags false stops managing those
settings; existing retention/quota remain until an operator deliberately removes
them. See [the operations runbook](OPERATIONS.md).

Same-origin routing satisfies the browser origin constraint; it does not disable
CSP or make unsafe HTML safe. For Huawei private-cloud integration, see
[the platform-specific checklist](HUAWEI_PRIVATE_CLOUD.md) and the intentionally
unresolved `values-huawei.example.yaml` overlay. Public CCE documentation is not
proof of compatibility with your specific Huawei Cloud Stack/UCS installation.

## Existing Installations: Do Not Upgrade Volumes In Place

Official chart 26.8.12 changes PostgreSQL and RabbitMQ from Bitnami to CloudPirates
and upgrades PostgreSQL 17 to 18 and OpenSearch 2 to 3. A normal `helm upgrade` or
`--reuse-values` does **not** migrate the old database or storage layout.

Follow the [official migration guide](https://github.com/reportportal/kubernetes/wiki/Migration-v26)
in a planned maintenance window, with tested database/attachment backups and a
restore rehearsal. This local validation instead installs a new release in a new
namespace with independent PVCs. The old release and volumes are retained; no old
PVC is attached to the new PostgreSQL instance.

To pause an old local installation without deleting data, record the replica counts
before scaling its deployments/statefulsets to zero. Restore each recorded count to
resume it. Do not delete its namespace, PVCs or volumes. This is a local capacity
measure, not a production migration or zero-downtime upgrade strategy.

## Reproducibility And Checks

```sh
helm dependency build ./helm/reportportal-rich-experience
helm lint ./helm/reportportal-rich-experience
bundle exec rspec spec/helm/latest_chart_spec.rb
helm test reportportal-latest -n reportportal-latest --timeout 5m
```

Inspect actual pod image tags and health after deployment; `Running` alone is not
an API compatibility result. Client regression must reconcile native Cucumber
results, delivery receipts and fresh ReportPortal API items/logs, including failures
and attachments. See the release-specific validation record in `docs/reviews/`.

Upstream: [26.0.5 release](https://reportportal.io/docs/releases/Version26.0.5/)
and [chart 26.8.12](https://github.com/reportportal/kubernetes/releases/tag/reportportal-26.8.12).

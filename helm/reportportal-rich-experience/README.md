# ReportPortal Rich Experience Helm Chart

## Version Contract

Wrapper chart **1.2.0-rc.2** pins official chart **26.8.12**, ReportPortal **26.0.5**.
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
The included video Ingress uses NGINX-specific annotations; it is not a portable
Gateway API implementation. Ingress NGINX's retirement must be considered when
selecting a supported production controller.

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
helm install reportportal ./pkg/reportportal-rich-experience-1.2.0-rc.2.tgz \
  -n reportportal --create-namespace -f ./production-values.yaml \
  --wait --wait-for-jobs --timeout 20m
```

The production example intentionally disables the legacy video bucket extension.
The default/local `mc anonymous set public` policy also allows anonymous writes and
deletes. It is **not read-only** and remains a known security limitation, explicitly
outside this upgrade's repair scope. `makePublic=false` or `enabled=false` does not
revoke an existing bucket's permissions. Before exposing video storage in production,
apply and verify a restricted policy, retention and authorization appropriate to
your evidence data. Same-origin routing satisfies the browser origin constraint;
it does not disable CSP or make unsafe HTML safe.

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

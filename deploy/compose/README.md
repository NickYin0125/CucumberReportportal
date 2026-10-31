# ReportPortal 26.0.7 With Docker Compose

The repository root `docker-compose.yml` pins the official 26.0.7 service versions
and adds the same read-only video bucket policy and 30-day retention used by our
Helm extension. The Ruby SDK version is unchanged. This is a **single-machine local
validation profile**, not a TLS/HA/backup configuration for production.
Run it from a source checkout, not from the installed gem's directory.
MinIO and mc use available, pinned `bitnamilegacy` images because the original
MinIO image endpoints denied fresh pulls. Archive and scan them in your own image
registry before offline use; this RP upgrade does not modernize MinIO itself.

## Start

Install Docker Engine/Desktop and Docker Compose v2. Copy `deploy/compose/.env.example` to a
private file outside Git, fill every password, and restrict it to mode 600. Use
unique URL-safe secrets; the analyzer places its broker password in an AMQP URI.
Run from the repository root:

```sh
docker compose --env-file /secure/path/reportportal.env config --quiet
docker compose --env-file /secure/path/reportportal.env pull
docker compose --env-file /secure/path/reportportal.env up -d --wait --wait-timeout 600
docker compose --env-file /secure/path/reportportal.env ps -a
```

Open `http://localhost:28080/ui/` and log in as `superadmin` with the password you
provided. `RP_INITIAL_ADMIN_PASSWORD` initializes a new database only; changing it
does not reset an existing account. Set `RP_COMPOSE_PORT` to change the loopback
port. No database, broker, search, MinIO console or gateway admin port is published,
and the gateway uses static routes rather than mounting Docker's control socket.

API, authorization and jobs wait for database migrations. The gateway waits for successful
video-bucket initialization, including during `up --wait`. Rootless analyzer storage is
initialized separately with UID/GID 65532; it does not chown the RP attachment
volume. Named volumes are scoped to project `reportportal-2607`; use `--project-name`
for another independent instance. Never reuse old PostgreSQL 17/OpenSearch 2 data
volumes. Upgrades require tested backups and dependency-specific upgrade planning.

## Client And Video Configuration

```sh
export RP_ENDPOINT=http://localhost:28080
export RP_PROJECT=superadmin_personal
export RP_CLIENT_JOIN=false
export RP_API_KEY='<your API key>'
export RP_VIDEO_UPLOAD_MODE=minio_markdown
export RP_MINIO_ENDPOINT=http://localhost:28080
export RP_MINIO_PUBLIC_BASE_URL=http://localhost:28080
export RP_MINIO_BUCKET=automation-videos
export RP_MINIO_ACCESS_KEY_ID=rpuser
# Supply RP_MINIO_SECRET_ACCESS_KEY securely using your MINIO_PASSWORD.
bundle exec rake rp:regression
```

Native RP attachments use the shared filesystem; completed MP4 files use the
dedicated MinIO volume and same-origin `/automation-videos` route. Anonymous
access grants **GetObject only**, never listing, upload or deletion. The initializer
reuses Helm's reconciliation script, overwrites legacy grants, applies 30-day
expiry and enforces a default 4 GiB video quota. Quota is not a host disk reservation;
monitor Docker disk usage and size it for your recordings. Never expose this
local HTTP profile directly outside your trusted environment.

To revoke anonymous reads without deleting recordings, set
`VIDEO_ANONYMOUS_READ=false` and rerun the initializer:

```sh
docker compose --env-file /secure/path/reportportal.env run --rm video-bucket-init
```

Stop while preserving reports with `docker compose --env-file /secure/path/reportportal.env stop`.
Do not use `down -v` unless you deliberately intend to delete the project's data.
See the [Helm operations runbook](../../helm/reportportal-rich-experience/OPERATIONS.md)
for retention, backup and capacity considerations.

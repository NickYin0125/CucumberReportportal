#!/bin/sh
set -eu

# This Job owns policy and lifecycle on a dedicated automation-video bucket.
configuration="${MINIO_CONFIGURATION_DIR:-/configuration}"
alias_name="reportportal"
target="${alias_name}/${MINIO_BUCKET}"
export MC_CONFIG_DIR="${MC_CONFIG_DIR:-/tmp/mc-config}"
export MC_NO_COLOR=1

i=1
until mc alias set "${alias_name}" "${MINIO_ENDPOINT}" "${MINIO_ACCESS_KEY}" "${MINIO_SECRET_KEY}" >/dev/null; do
  if [ "${i}" -ge "${MINIO_WAIT_ATTEMPTS}" ]; then
    echo "MinIO readiness failed; bucket security was NOT reconciled" >&2
    exit 1
  fi
  i=$((i + 1))
  sleep "${MINIO_WAIT_SLEEP_SECONDS}"
done

if [ "${MINIO_BUCKET_ENABLED}" = "true" ]; then
  mc mb --ignore-existing "${target}"
else
  # stat converts a missing bucket to untyped object errors in this mc release;
  # get-json preserves the backend S3 error code needed for safe revocation.
  if ! state="$(mc --json anonymous get-json "${target}" 2>&1)"; then
    # The pinned mc image has no grep/jq. Match the explicit JSON error code,
    # never a free-text 'not found' message or an arbitrary inspection failure.
    case "${state}" in
      *'"Code":"NoSuchBucket"'*|*'"Code": "NoSuchBucket"'*|*'"code":"NoSuchBucket"'*|*'"code": "NoSuchBucket"'*)
        echo "Video bucket absent; anonymous access is already unavailable"
        exit 0
        ;;
      *'"Code":"NoSuchBucketPolicy"'*|*'"Code": "NoSuchBucketPolicy"'*|*'"code":"NoSuchBucketPolicy"'*|*'"code": "NoSuchBucketPolicy"'*)
        # Existing bucket, already private: still apply the explicit empty policy.
        :
        ;;
      *)
        echo "Cannot inspect disabled video bucket; revocation was NOT verified" >&2
        exit 1
        ;;
    esac
  fi
fi

# set-json replaces the entire old policy, including legacy prefix write grants.
policy="${configuration}/private.json"
if [ "${MINIO_BUCKET_ENABLED}" = "true" ] && [ "${MINIO_MAKE_PUBLIC}" = "true" ]; then
  policy="${configuration}/read-only.json"
fi
mc anonymous set-json "${policy}" "${target}"

if [ "${MINIO_BUCKET_ENABLED}" != "true" ]; then
  echo "Video bucket disabled; previous anonymous grants revoked without deleting objects"
  exit 0
fi

if [ "${MINIO_RETENTION_ENABLED}" = "true" ]; then
  # Import one stable rule instead of accumulating a random rule on every upgrade.
  mc ilm rule import "${target}" <"${configuration}/lifecycle.json"
fi
if [ "${MINIO_QUOTA_ENABLED}" = "true" ]; then
  mc quota set "${target}" --size "${MINIO_QUOTA_SIZE}"
fi

if [ -n "${MINIO_OBJECT_PREFIX}" ]; then
  keep_file="$(mktemp)"
  trap 'rm -f "${keep_file}"' EXIT
  mc cp "${keep_file}" "${target}/${MINIO_OBJECT_PREFIX%/}/.keep"
fi
echo "Video bucket reconciled: anonymous grants restricted or revoked; retention/quota failures are fatal"

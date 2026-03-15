#!/bin/sh
set -e

# Create S3 bucket if configured (wait for MinIO to be ready)
if [ -n "$S3_ENDPOINT" ]; then
  # Auto-prepend scheme if missing: http for internal, https for public
  case "$S3_ENDPOINT" in
    http://*|https://*) ;;
    *.railway.internal*) S3_ENDPOINT="http://${S3_ENDPOINT}"; export S3_ENDPOINT ;;
    *) S3_ENDPOINT="https://${S3_ENDPOINT}"; export S3_ENDPOINT ;;
  esac
  echo "Waiting for S3/MinIO (${S3_ENDPOINT})..."
  for i in $(seq 1 30); do
    python3 << 'PYEOF' && break || sleep 2
import os, boto3
from botocore.exceptions import ClientError
client = boto3.client('s3',
    endpoint_url=os.environ['S3_ENDPOINT'],
    aws_access_key_id=os.environ['S3_ACCESS_KEY'],
    aws_secret_access_key=os.environ['S3_SECRET_KEY'],
    region_name=os.environ.get('S3_REGION', 'us-east-1'))
bucket = os.environ.get('S3_BUCKET', 'odoo')
try:
    client.head_bucket(Bucket=bucket)
    print(f'S3 bucket "{bucket}" is ready')
except ClientError as e:
    if e.response['Error']['Code'] in ('404', 'NoSuchBucket'):
        client.create_bucket(Bucket=bucket)
        print(f'Created S3 bucket: {bucket}')
    else:
        raise
PYEOF
  done

  # Sync local filestore → S3 on every startup
  echo "Syncing filestore to S3..."
  python3 << 'PYEOF'
import os, boto3
from botocore.exceptions import ClientError

client = boto3.client('s3',
    endpoint_url=os.environ['S3_ENDPOINT'],
    aws_access_key_id=os.environ['S3_ACCESS_KEY'],
    aws_secret_access_key=os.environ['S3_SECRET_KEY'],
    region_name=os.environ.get('S3_REGION', 'us-east-1'))
bucket = os.environ.get('S3_BUCKET', 'odoo')
data_dir = os.environ.get('ODOO_DATA_DIR', '/var/lib/odoo')
filestore_root = os.path.join(data_dir, 'filestore')

if not os.path.isdir(filestore_root):
    print('No filestore found, skipping sync')
else:
    synced = 0
    skipped = 0
    for db_name in os.listdir(filestore_root):
        db_path = os.path.join(filestore_root, db_name)
        if not os.path.isdir(db_path):
            continue
        for root, dirs, files in os.walk(db_path):
            for fname in files:
                full_path = os.path.join(root, fname)
                key = os.path.relpath(full_path, db_path)
                try:
                    client.head_object(Bucket=bucket, Key=key)
                    skipped += 1
                except ClientError:
                    with open(full_path, 'rb') as f:
                        client.put_object(Bucket=bucket, Key=key, Body=f.read())
                    synced += 1
    print(f'Filestore sync: {synced} uploaded, {skipped} already on S3')
PYEOF
fi

# Build argument list using set -- to handle values with spaces safely
set -- odoo
set -- "$@" "--addons-path=${ODOO_ADDONS_PATH:-/mnt/extra-addons,/usr/lib/python3/dist-packages/odoo/addons}"
set -- "$@" "--data-dir=${ODOO_DATA_DIR:-/var/lib/odoo}"
set -- "$@" "--http-port=${ODOO_PORT:-8069}"
set -- "$@" "--gevent-port=${ODOO_GEVENT_PORT:-8072}"

# Boolean flags (default True unless explicitly set to False)
case "${ODOO_PROXY_MODE:-True}" in
  [Ff]alse|0|no) ;;
  *) set -- "$@" "--proxy-mode" ;;
esac

case "${ODOO_WITHOUT_DEMO:-True}" in
  [Ff]alse|0|no) ;;
  *) set -- "$@" "--without-demo=True" ;;
esac

# --- Admin ---
[ -n "$ODOO_ADMIN_PASSWORD" ] && set -- "$@" "--admin-passwd=${ODOO_ADMIN_PASSWORD}"

# --- Workers & Limits ---
[ -n "$ODOO_WORKERS" ]            && set -- "$@" "--workers=${ODOO_WORKERS}"
[ -n "$ODOO_MAX_CRON_THREADS" ]   && set -- "$@" "--max-cron-threads=${ODOO_MAX_CRON_THREADS}"
[ -n "$ODOO_LIMIT_MEMORY_HARD" ]  && set -- "$@" "--limit-memory-hard=${ODOO_LIMIT_MEMORY_HARD}"
[ -n "$ODOO_LIMIT_MEMORY_SOFT" ]  && set -- "$@" "--limit-memory-soft=${ODOO_LIMIT_MEMORY_SOFT}"
[ -n "$ODOO_LIMIT_TIME_CPU" ]     && set -- "$@" "--limit-time-cpu=${ODOO_LIMIT_TIME_CPU}"
[ -n "$ODOO_LIMIT_TIME_REAL" ]    && set -- "$@" "--limit-time-real=${ODOO_LIMIT_TIME_REAL}"
[ -n "$ODOO_LIMIT_REQUEST" ]      && set -- "$@" "--limit-request=${ODOO_LIMIT_REQUEST}"

# --- Database ---
set -- "$@" "--db_host=${ODOO_DATABASE_HOST:-localhost}"
set -- "$@" "--db_port=${ODOO_DATABASE_PORT:-5432}"
set -- "$@" "--db_user=${ODOO_DATABASE_USER:-odoo}"
set -- "$@" "--db_password=${ODOO_DATABASE_PASSWORD:-odoo}"
set -- "$@" "--database=${ODOO_DATABASE_NAME:-odoo}"
[ -n "$ODOO_DB_MAXCONN" ]  && set -- "$@" "--db_maxconn=${ODOO_DB_MAXCONN}"
[ -n "$ODOO_DB_TEMPLATE" ] && set -- "$@" "--db-template=${ODOO_DB_TEMPLATE}"
[ -n "$ODOO_DB_SSLMODE" ]  && set -- "$@" "--db_sslmode=${ODOO_DB_SSLMODE}"
[ -n "$ODOO_DBFILTER" ]    && set -- "$@" "--db-filter=${ODOO_DBFILTER}"
[ -n "$ODOO_LIST_DB" ]     && set -- "$@" "--list-db=${ODOO_LIST_DB}"
[ -n "$ODOO_UNACCENT" ]    && set -- "$@" "--unaccent"

# --- Logging ---
[ -n "$ODOO_LOG_LEVEL" ]   && set -- "$@" "--log-level=${ODOO_LOG_LEVEL}"
[ -n "$ODOO_LOG_HANDLER" ] && set -- "$@" "--log-handler=${ODOO_LOG_HANDLER}"
[ -n "$ODOO_LOG_DB" ]      && set -- "$@" "--log-db=${ODOO_LOG_DB}"
[ -n "$ODOO_LOGFILE" ]     && set -- "$@" "--logfile=${ODOO_LOGFILE}"

# --- SMTP (optional — only add if ODOO_SMTP_HOST is set) ---
if [ -n "$ODOO_SMTP_HOST" ]; then
  set -- "$@" "--smtp=${ODOO_SMTP_HOST}"
  set -- "$@" "--smtp-port=${ODOO_SMTP_PORT:-587}"
  [ -n "$ODOO_SMTP_USER" ]     && set -- "$@" "--smtp-user=${ODOO_SMTP_USER}"
  [ -n "$ODOO_SMTP_PASSWORD" ] && set -- "$@" "--smtp-password=${ODOO_SMTP_PASSWORD}"
  [ -n "$ODOO_SMTP_SSL" ]      && set -- "$@" "--smtp-ssl=${ODOO_SMTP_SSL}"
  [ -n "$ODOO_EMAIL_FROM" ]    && set -- "$@" "--email-from=${ODOO_EMAIL_FROM}"
fi

# --- Modules ---
[ -n "$ODOO_INIT" ]   && set -- "$@" "--init=${ODOO_INIT}"
[ -n "$ODOO_UPDATE" ] && set -- "$@" "--update=${ODOO_UPDATE}"

# --- Dev mode ---
[ -n "$ODOO_DEV" ] && set -- "$@" "--dev=${ODOO_DEV}"

exec "$@" 2>&1

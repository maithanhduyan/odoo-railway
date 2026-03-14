#!/bin/sh
set -e

# Create S3 bucket if configured (wait for MinIO to be ready)
if [ -n "$S3_ENDPOINT" ]; then
  echo "Waiting for S3/MinIO..."
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
fi

# Build argument list using set -- to handle values with spaces safely
set -- odoo
set -- "$@" "--http-port=${ODOO_PORT:-8069}"
set -- "$@" "--gevent-port=${ODOO_GEVENT_PORT:-8072}"
set -- "$@" "--proxy-mode"
set -- "$@" "--without-demo=True"

# Database (required)
set -- "$@" "--db_host=${ODOO_DATABASE_HOST}"
set -- "$@" "--db_port=${ODOO_DATABASE_PORT:-5432}"
set -- "$@" "--db_user=${ODOO_DATABASE_USER}"
set -- "$@" "--db_password=${ODOO_DATABASE_PASSWORD}"
set -- "$@" "--database=${ODOO_DATABASE_NAME}"

# SMTP (optional — only add if ODOO_SMTP_HOST is set)
if [ -n "$ODOO_SMTP_HOST" ]; then
  set -- "$@" "--smtp=${ODOO_SMTP_HOST}"
  set -- "$@" "--smtp-port=${ODOO_SMTP_PORT_NUMBER:-587}"
  [ -n "$ODOO_SMTP_USER" ]     && set -- "$@" "--smtp-user=${ODOO_SMTP_USER}"
  [ -n "$ODOO_SMTP_PASSWORD" ] && set -- "$@" "--smtp-password=${ODOO_SMTP_PASSWORD}"
  [ -n "$ODOO_EMAIL_FROM" ]    && set -- "$@" "--email-from=${ODOO_EMAIL_FROM}"
fi

# Init modules on first deploy only (set ODOO_INIT=base or ODOO_INIT=all)
if [ -n "$ODOO_INIT" ]; then
  set -- "$@" "--init=${ODOO_INIT}"
fi

exec "$@" 2>&1


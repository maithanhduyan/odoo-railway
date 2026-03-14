#!/bin/sh
set -e

# MinIO API on fixed port 9000 (internal access from Odoo)
# MinIO Console on $PORT (public access via Railway)
exec minio server /data \
  --address ":9000" \
  --console-address ":${PORT:-9001}" \
  2>&1

#!/bin/bash
# Fetch the latest minor version for a given PostgreSQL major version
# Usage: ./get-postgres-version.sh <major_version>
# Example: ./get-postgres-version.sh 17  =>  17.4

set -euo pipefail

MAJOR="${1:?Usage: $0 <major_version>}"

# Query Docker Hub API for available tags matching this major version
VERSION=$(curl -fsSL "https://registry.hub.docker.com/v2/repositories/library/postgres/tags?page_size=100&name=${MAJOR}." \
  | grep -oP "\"name\":\\s*\"${MAJOR}\\.\\d+\"" \
  | grep -oP "${MAJOR}\\.\\d+" \
  | sort -t. -k2 -n \
  | tail -1)

if [ -z "$VERSION" ]; then
  echo "ERROR: Could not find any version for PostgreSQL ${MAJOR}" >&2
  exit 1
fi

echo "$VERSION"

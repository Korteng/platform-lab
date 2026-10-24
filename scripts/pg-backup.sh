#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
f="backups/fm-$(date +%Y%m%d-%H%M%S).dump"
kubectl -n finance-manager exec postgres-0 -- sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > "$f"
test -s "$f"
head -c5 "$f" | grep -q PGDMP
sha256sum "$f" > "$f.sha256"
scripts/pg-counts.sh > "$f.counts"
echo "dump: $f ($(du -h "$f" | cut -f1))"
cat "$f.counts"

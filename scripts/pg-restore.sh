#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
f="${1:-$(ls -1t backups/fm-*.dump | head -1)}"
echo "restore from: $f"
sha256sum -c "$f.sha256"
kubectl -n finance-manager exec -i postgres-0 -- sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists --no-owner' < "$f"
scripts/pg-counts.sh > backups/after-restore.counts
diff -u "$f.counts" backups/after-restore.counts && echo "OK: row counts match the backup"

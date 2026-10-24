#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "BEFORE:"; scripts/pg-counts.sh
kubectl -n finance-manager exec -i postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1' <<'SQL'
TRUNCATE "transaction", budget;
SQL
echo "AFTER:"; scripts/pg-counts.sh

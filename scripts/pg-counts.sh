#!/usr/bin/env bash
set -euo pipefail
kubectl -n finance-manager exec -i postgres-0 -- sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -At -F "|"' <<'SQL'
select 'app_user', count(*) from app_user
union all select 'budget', count(*) from budget
union all select 'category', count(*) from category
union all select 'transaction', count(*) from "transaction"
order by 1;
SQL

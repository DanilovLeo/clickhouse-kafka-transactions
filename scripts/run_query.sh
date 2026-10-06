#!/usr/bin/env bash
# П.3. Выполняет sql/03_query.sql и сохраняет результат в results/
set -euo pipefail
cd "$(dirname "$0")/.."
CLIENT=${CLIENT:-"docker compose exec -T clickhouse clickhouse-client"}
OUT=results/max_transaction_category_by_state.csv

mkdir -p results
$CLIENT --format CSVWithNames < sql/03_query.sql > "$OUT"
echo "Saved $(($(wc -l < "$OUT") - 1)) rows to $OUT"

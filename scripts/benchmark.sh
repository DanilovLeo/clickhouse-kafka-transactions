#!/usr/bin/env bash
# П.4. Сравнение базовой и оптимизированной таблиц: размер на диске и скорость целевого запроса.
set -euo pipefail
cd "$(dirname "$0")/.."
CLIENT=${CLIENT:-"docker compose exec -T clickhouse clickhouse-client"}
RUNS=${RUNS:-10}
QUERY=$(cat sql/03_query.sql)
TAG="bench_$(date +%s)"

echo "== Размер таблиц на диске"
$CLIENT -q "
    SELECT table, sum(rows) AS rows, count() AS parts,
           formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed,
           formatReadableSize(sum(bytes_on_disk))           AS on_disk
    FROM system.parts
    WHERE active AND database = currentDatabase()
      AND table IN ('transactions_baseline', 'transactions')
    GROUP BY table ORDER BY table
    FORMAT PrettyCompactMonoBlock"

echo "== Целевой запрос, ${RUNS} запусков на каждую таблицу"
for table in transactions_baseline transactions; do
    q=${QUERY/FROM transactions/FROM $table}
    for _ in $(seq "$RUNS"); do
        $CLIENT --log_comment="${TAG}:${table}" --use_query_cache=0 -q "$q" > /dev/null
    done
done

$CLIENT -q "SYSTEM FLUSH LOGS"
$CLIENT -q "
    SELECT splitByChar(':', log_comment)[2]          AS table,
           round(avg(query_duration_ms), 1)          AS avg_ms,
           round(avg(read_rows))                     AS read_rows,
           formatReadableSize(avg(read_bytes))       AS read_bytes,
           formatReadableSize(avg(memory_usage))     AS memory,
           arrayStringConcat(any(projections), ', ') AS projection_used
    FROM system.query_log
    WHERE type = 'QueryFinish' AND log_comment LIKE '${TAG}:%'
    GROUP BY table ORDER BY table
    FORMAT PrettyCompactMonoBlock"

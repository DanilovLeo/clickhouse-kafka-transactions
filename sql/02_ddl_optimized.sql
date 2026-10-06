-- =====================================================================
-- П.4. Оптимизированная схема хранения (изменённый DDL из п.2).
-- Читает тот же топик через ту же очередь transactions_queue.
--
-- Что изменено относительно transactions_baseline:
--   1. Типы: LowCardinality(String) для повторяющихся строк (все текстовые поля
--      имеют < 1000 уникальных значений), DateTime вместо строки,
--      Decimal(9, 2) для суммы (точно, 4 байта), беззнаковые целые нужной ширины.
--   2. Ключ сортировки (us_state, cat_id, transaction_time): строки одного штата
--      лежат рядом, GROUP BY us_state читает данные по порядку, сжатие лучше.
--   3. Кодеки сжатия: Delta + ZSTD для времени, ZSTD для чисел.
--   4. Агрегирующая проекция: для каждого штата заранее хранится категория
--      и сумма самой крупной транзакции. Целевой запрос читает ~51 строку
--      вместо всей таблицы.
-- =====================================================================

CREATE TABLE IF NOT EXISTS transactions
(
    transaction_time DateTime('UTC')        CODEC(Delta, ZSTD(1)),
    merch            LowCardinality(String),
    cat_id           LowCardinality(String),
    amount           Decimal(9, 2)          CODEC(ZSTD(1)),
    name_1           LowCardinality(String),
    name_2           LowCardinality(String),
    gender           LowCardinality(String),
    street           LowCardinality(String),
    one_city         LowCardinality(String),
    us_state         LowCardinality(String),
    post_code        UInt32                 CODEC(ZSTD(1)),
    lat              Float64                CODEC(ZSTD(1)),
    lon              Float64                CODEC(ZSTD(1)),
    population_city  UInt32                 CODEC(ZSTD(1)),
    jobs             LowCardinality(String),
    merchant_lat     Float64                CODEC(ZSTD(1)),
    merchant_lon     Float64                CODEC(ZSTD(1)),
    target           UInt8,

    PROJECTION max_transaction_by_state
    (
        SELECT us_state, argMax(cat_id, amount), max(amount)
        GROUP BY us_state
    )
)
ENGINE = MergeTree
ORDER BY (us_state, cat_id, transaction_time);

CREATE MATERIALIZED VIEW IF NOT EXISTS transactions_mv TO transactions AS
SELECT
    parseDateTimeBestEffort(transaction_time, 'UTC') AS transaction_time,
    merch, cat_id, amount, name_1, name_2, gender, street, one_city, us_state,
    toUInt32(post_code) AS post_code, lat, lon,
    toUInt32(population_city) AS population_city, jobs,
    merchant_lat, merchant_lon, toUInt8(target) AS target
FROM transactions_queue;

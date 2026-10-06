-- =====================================================================
-- П.2. Базовая схема: Kafka -> Materialized View -> MergeTree
-- Выполняется автоматически при первом старте ClickHouse.
-- =====================================================================

-- Таблица-очередь: читает JSON-сообщения из топика transactions.
-- Сама данные не хранит, это только точка входа из Kafka.
CREATE TABLE IF NOT EXISTS transactions_queue
(
    transaction_time String,
    merch            String,
    cat_id           String,
    amount           Decimal(9, 2),
    name_1           String,
    name_2           String,
    gender           String,
    street           String,
    one_city         String,
    us_state         String,
    post_code        Int64,
    lat              Float64,
    lon              Float64,
    population_city  Int64,
    jobs             String,
    merchant_lat     Float64,
    merchant_lon     Float64,
    target           Int64
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'kafka:9092',
    kafka_topic_list = 'transactions',
    kafka_group_name = 'clickhouse-transactions',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 1,
    kafka_skip_broken_messages = 100;

-- Таблица хранения "как есть": все поля со стандартными типами, без сортировки и сжатия.
CREATE TABLE IF NOT EXISTS transactions_baseline
(
    transaction_time String,
    merch            String,
    cat_id           String,
    amount           Float64,
    name_1           String,
    name_2           String,
    gender           String,
    street           String,
    one_city         String,
    us_state         String,
    post_code        Int64,
    lat              Float64,
    lon              Float64,
    population_city  Int64,
    jobs             String,
    merchant_lat     Float64,
    merchant_lon     Float64,
    target           Int64
)
ENGINE = MergeTree
ORDER BY tuple();

-- Перекладывает каждую новую пачку сообщений из очереди в таблицу хранения.
CREATE MATERIALIZED VIEW IF NOT EXISTS transactions_baseline_mv TO transactions_baseline AS
SELECT
    transaction_time, merch, cat_id, toFloat64(amount) AS amount, name_1, name_2, gender,
    street, one_city, us_state, post_code, lat, lon, population_city, jobs,
    merchant_lat, merchant_lon, target
FROM transactions_queue;

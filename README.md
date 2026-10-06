# Kafka → ClickHouse: транзакции по штатам

Данные из CSV загружаются в Kafka, ClickHouse читает топик и сохраняет данные в таблицу.
Затем выполняется SQL-запрос: категория наибольшей транзакции в каждом штате.
Отдельно сделана оптимизированная схема хранения, и проведено её сравнение с базовой.

## Архитектура

```
data/train.csv ──> producer ──> Kafka [transactions] ──> transactions_queue (Kafka engine)
                                                          ├─ transactions_baseline_mv ──> transactions_baseline  (п.2)
                                                          └─ transactions_mv ──────────> transactions           (п.4)
```

| Файл | Пункт задания |
|---|---|
| `producer/produce.py` | п.1 — загрузка CSV в топик Kafka (одна строка = одно JSON-сообщение) |
| `sql/01_ddl.sql` | п.2 — DDL: Kafka-таблица, базовая таблица хранения, materialized view |
| `sql/03_query.sql` | п.3 — запрос: категория наибольшей транзакции по штату |
| `results/max_transaction_category_by_state.csv` | п.3 — результат запроса |
| `sql/02_ddl_optimized.sql` | п.4 — оптимизированный DDL |

DDL выполняется автоматически при первом старте ClickHouse.

## Запуск

Нужны Docker и Docker Compose v2, свободные порты 9095 и 8123.

1. Скачайте датасет с Kaggle и положите файл в `data/train.csv`.
2. Поднимите сервисы:
   ```bash
   docker compose up -d
   docker compose ps
   ```
   Должны быть запущены `kafka`, `zookeeper` и `clickhouse` (со статусом `healthy`).
3. Загрузите CSV в Kafka (около минуты):
   ```bash
   docker compose run --rm producer
   ```
4. Через 10–15 секунд проверьте, что ClickHouse прочитал все строки (должно быть `786431`):
   ```bash
   docker compose exec clickhouse clickhouse-client -q "SELECT count() FROM transactions"
   ```

Остановка с удалением данных: `docker compose down -v`. Повторный запуск producer без очистки продублирует строки.

## Запрос (п.3)

```sql
SELECT us_state, argMax(cat_id, amount) AS category, max(amount) AS max_amount
FROM transactions
GROUP BY us_state
ORDER BY us_state
```

`argMax(cat_id, amount)` возвращает категорию из строки с максимальной суммой.
Выполнить запрос и сохранить результат в `results/`:

```bash
./scripts/run_query.sh
```

Результат — 51 штат. В 35 штатах крупнейшая транзакция относится к категории `travel`,
в остальных — к `shopping_pos` и `shopping_net`.

## Оптимизация (п.4)

Изменения относительно базовой таблицы:

- **Типы данных:** `LowCardinality(String)` для всех текстовых полей (у каждого меньше 1000 уникальных значений),
  `DateTime` вместо строки, `Decimal(9, 2)` для суммы, `UInt8` и `UInt32` вместо `Int64`.
- **Ключ сортировки** `(us_state, cat_id, transaction_time)`: строки одного штата лежат рядом, данные лучше сжимаются.
- **Кодеки сжатия:** `Delta + ZSTD` для времени, `ZSTD` для чисел.
- **Агрегирующая проекция** `max_transaction_by_state`: для каждого штата заранее хранится категория
  и сумма крупнейшей транзакции. Запрос читает по 51 строке на каждый кусок (part) таблицы вместо всех строк.

Сравнение на полном датасете (786 431 строк):

| | `transactions_baseline` | `transactions` |
|---|---|---|
| Размер на диске | 58.4 MiB | 24.1 MiB |
| Время запроса | 17.7 ms | 3.4 ms |
| Прочитано строк | 786 431 | 102 |

Воспроизвести сравнение:

```bash
./scripts/benchmark.sh
```

Скрипт выводит размеры таблиц и среднее время запроса по 10 запускам для каждой таблицы.
Он также показывает, какая проекция использовалась. Абсолютные значения зависят от машины.
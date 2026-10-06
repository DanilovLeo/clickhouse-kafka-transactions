"""
П.1. Загрузка CSV в топик Kafka: каждая строка файла -> одно JSON-сообщение.

Запуск в контейнере (см. README):
    docker compose run --rm producer
Запуск с хоста:
    pip install -r producer/requirements.txt
    python producer/produce.py --csv data/train.csv --bootstrap localhost:9095
"""
import argparse
import json
import logging
import os
import sys
import time

import pandas as pd
from confluent_kafka import Producer

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
logger = logging.getLogger("producer")

CHUNK_SIZE = 50_000


def chunk_to_messages(chunk: pd.DataFrame):
    """DataFrame -> JSON-строки. NaN превращается в null, numpy-типы — в обычные python-типы."""
    records = chunk.astype(object).where(chunk.notna(), None).to_dict(orient="records")
    return [json.dumps(r, ensure_ascii=False) for r in records]


def delivery_report(err, msg):
    if err is not None:
        logger.error("Delivery failed: %s", err)


def main():
    parser = argparse.ArgumentParser(description="Load CSV rows into a Kafka topic as JSON")
    parser.add_argument("--csv", default=os.getenv("CSV_PATH", "data/train.csv"))
    parser.add_argument("--bootstrap", default=os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9095"))
    parser.add_argument("--topic", default=os.getenv("KAFKA_TOPIC", "transactions"))
    args = parser.parse_args()

    if not os.path.exists(args.csv):
        logger.error("File %s not found. Download the dataset from Kaggle into the data/ folder.", args.csv)
        sys.exit(1)

    producer = Producer({
        "bootstrap.servers": args.bootstrap,
        "linger.ms": 50,
        "batch.num.messages": 10_000,
        "compression.type": "lz4",
        "queue.buffering.max.messages": 500_000,
    })

    logger.info("Sending %s to topic '%s' at %s", args.csv, args.topic, args.bootstrap)
    started, sent = time.time(), 0
    for chunk in pd.read_csv(args.csv, chunksize=CHUNK_SIZE):
        for value in chunk_to_messages(chunk):
            while True:
                try:
                    producer.produce(args.topic, value=value.encode("utf-8"), callback=delivery_report)
                    break
                except BufferError:  # локальная очередь заполнена — ждём, пока сообщения уйдут
                    producer.poll(0.5)
            producer.poll(0)
        sent += len(chunk)
        logger.info("Sent %d rows", sent)

    remaining = producer.flush(60)
    if remaining:
        logger.error("%d messages were not delivered", remaining)
        sys.exit(1)
    logger.info("Done: %d messages in %.1f s", sent, time.time() - started)


if __name__ == "__main__":
    main()

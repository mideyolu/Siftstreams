# Suggested project structure

```text
siftstreams/
├── backend/
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── events.py
│   │   │   ├── analytics.py
│   │   │   └── health.py
│   │   ├── core/
│   │   │   └── config.py
│   │   ├── db/
│   │   │   ├── session.py
│   │   │   └── models/
│   │   ├── schemas/
│   │   │   └── events.py
│   │   ├── services/
│   │   │   ├── event_ingestion.py
│   │   │   └── analytics.py
│   │   ├── workers/
│   │   │   └── event_consumer.py
│   │   └── main.py
│   ├── migrations/
│   │   └── 001_initial_schema.sql
│   └── tests/
│       ├── unit/
│       ├── integration/
│       └── contract/
├── frontend/
├── simulator/
├── infra/
│   └── docker-compose.yml
├── docs/
│   └── project-structure.md
├── .env.example
└── README.md
```

## Processing contract

1. Validate an event before publishing it.
2. Append the event to Redis Streams.
3. Return `202 Accepted` only after Redis confirms the append.
4. Read through a consumer group.
5. Apply business writes and insert the unique event record in one PostgreSQL transaction.
6. Commit the transaction.
7. Acknowledge the Redis message.
8. On redelivery, use the event ID and business identifiers (payment ID/refund ID) to avoid repeating effects.

## Notes for the next iteration

- Add an `order_items` pricing/currency consistency check at the service or database level.
- If orders may contain multiple currencies (normally they should not), define that explicitly; otherwise enforce order-item currency equals order currency in application logic or with a stronger relational design.
- Consider whether `UNIQUE(order_id, product_id)` is suitable. It is convenient for a first version; alternatively allow repeated product rows and identify each row with a client-provided line-item ID.
- Define how product-view events referencing not-yet-created products are handled. For event analytics, keeping `product_id` as an unconstrained identifier in `events` can be preferable to rejecting an otherwise valid event.
- For robust event intake across Redis outages, consider a PostgreSQL inbox/outbox design or another durable acceptance mechanism; a Redis append alone depends on Redis persistence and availability configuration.
- Do not use the initial `events.processing_status` column as a full retry state machine. Stream pending state and dead-letter details should be designed separately.

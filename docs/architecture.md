# SiftStreams foundation architecture

## Current Phase 1 runtime

- `web`: Vite/React placeholder UI, served on port 5173.
- `api`: FastAPI health endpoints, served on port 8000.
- `postgres`: PostgreSQL schema initialized from the versioned migration on first empty-volume startup.
- `redis`: Redis 7 with append-only persistence enabled for local development.

## Planned event path (not implemented in this phase)

Client/simulator -> FastAPI validation -> Redis Streams -> worker consumer group -> PostgreSQL transaction -> analytics API -> dashboard.

## Key invariants

1. PostgreSQL is the source of truth for business records and money.
2. Event delivery is at-least-once; business processing must be idempotent.
3. A stream entry must not be acknowledged until the relevant database transaction commits.
4. Revenue is computed per currency as successful payments minus successful refunds.
5. API latency, processing lag, and event-to-dashboard freshness are distinct measurements.

## Schema notes to revisit before ingestion

- `orders` and `order_items` are first-class tables. Each order item stores quantity and unit price at purchase time; currency is inherited from the parent order.
- `events.product_id` intentionally has no product foreign key, because a view event may arrive before the catalogue record. Commerce writes should still enforce valid product IDs.
- The current `events.processing_status` is a simple lifecycle field, not a complete retry ledger. Retry attempts, scheduled retry time, and dead-letter details may warrant a separate table or stream.
- Cross-table currency consistency (order/payment/refund) should be enforced in application logic or by a deliberate composite-key constraint before financial event handling is implemented.
- The JSONB aggregate dimensions primary key must be validated with PostgreSQL and realistic query plans.

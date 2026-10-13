# Phase 1 validation

Run from the repository root after Docker is installed:

```bash
docker compose config
docker compose up --build -d
docker compose ps
curl http://localhost:8000/api/v1/health
curl http://localhost:8000/api/v1/health/dependencies
```

Expected dependency response:

```json
{
  "status": "ok",
  "service": "siftstreams-api",
  "dependencies": {
    "postgres": "ok",
    "redis": "ok"
  }
}
```

Check schema tables:

```bash
docker compose exec postgres psql -U siftstreams -d siftstreams -c "\dt"
```

Expected tables: products, orders, order_items, payments, refunds, events, metric_aggregates.

Run API contract test inside the API container:

```bash
docker compose exec api pytest -q
```

Run frontend production build (requires Node/npm on the host, or run from its container with an adapted command):

```bash
cd frontend
npm install
npm run build
```

Then return to the repo root and stop services:

```bash
docker compose down
```

The ZIP was statically checked while generated, but a live Docker/PostgreSQL/Redis integration test was not possible in the packaging environment because Docker is unavailable there. Mark Phase 1 complete only after the above commands pass locally.

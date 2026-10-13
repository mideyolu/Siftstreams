import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse


APP_NAME = "siftstreams-api"


def database_url() -> str:
    return os.environ.get(
        "DATABASE_URL",
        "postgresql://siftstreams:change-this-local-password@localhost:5432/siftstreams",
    )


def redis_url() -> str:
    return os.environ.get("REDIS_URL", "redis://localhost:6379/0")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Connections are created per health check for this minimal foundation.
    # Pooling can be added when implementing ingestion and analytics.
    yield


app = FastAPI(
    title="SiftStreams API",
    description="Foundation API. Event ingestion is not implemented yet.",
    version="0.1.0",
    lifespan=lifespan,
)


@app.get("/api/v1/health", tags=["health"])
async def health():
    return {"status": "ok", "service": APP_NAME}


@app.get("/api/v1/health/dependencies", tags=["health"])
async def dependency_health():
    import psycopg
    import redis.asyncio as redis

    checks = {}

    try:
        with psycopg.connect(database_url(), connect_timeout=2) as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                cur.fetchone()
        checks["postgres"] = "ok"
    except Exception:
        checks["postgres"] = "error"

    try:
        client = redis.from_url(redis_url(), socket_connect_timeout=2, socket_timeout=2)
        try:
            await client.ping()
            checks["redis"] = "ok"
        finally:
            await client.aclose()
    except Exception:
        checks["redis"] = "error"

    healthy = all(status == "ok" for status in checks.values())
    body = {
        "status": "ok" if healthy else "degraded",
        "service": APP_NAME,
        "dependencies": checks,
    }
    if not healthy:
        raise HTTPException(status_code=503, detail=body)
    return JSONResponse(content=body)

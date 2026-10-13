# SiftStreams

Real-time e-commerce analytics portfolio project. This repository is the Phase 1 foundation; event ingestion and worker processing are deliberately not implemented yet.

## Stack

- FastAPI + Python
- PostgreSQL 16
- Redis Streams (Redis 7; append-only persistence enabled for local development)
- React + TypeScript + Vite
- Docker Compose

## Prerequisites

Install Git, Docker Desktop (or Docker Engine with the Compose plugin), and a code editor. Verify:

```bash
git --version
docker --version
docker compose version
```

## 1. Create the GitHub repository

On GitHub, create a **new empty repository** named `siftstreams`. Do not initialize it with a README, license, or `.gitignore` because this starter already contains them.

Download/extract this starter, open a terminal in the extracted `siftstreams-phase1-complete` folder, then run:

```bash
git init
git add .
git commit -m "chore: establish SiftStreams foundation"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/siftstreams.git
git push -u origin main
```

Replace `YOUR_GITHUB_USERNAME` with your GitHub username. If you already have a repository, update the remote rather than adding a second one.

## 2. Configure local environment

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

The included password is only a local development default. Change it before sharing the repository or deploying. The `.env` file is ignored by Git.

## 3. Start the foundation

```bash
docker compose up --build
```

On first startup, PostgreSQL initializes the database and runs `backend/migrations/001_initial_schema.sql`. This init script only runs automatically when the database volume is empty.

Open:
- Frontend: http://localhost:5173
- API health: http://localhost:8000/api/v1/health
- Dependency health: http://localhost:8000/api/v1/health/dependencies
- API docs: http://localhost:8000/docs

Expected health response from `/api/v1/health`:

```json
{"status":"ok","service":"siftstreams-api"}
```

Dependency health should report PostgreSQL and Redis as `ok`. It returns HTTP 503 if a dependency cannot be reached.

## 4. Stop and reset

Stop containers but keep data:

```bash
docker compose down
```

Delete local database and Redis data (destructive; removes local data):

```bash
docker compose down -v
```

To rerun the init migration from a clean empty database, use `docker compose down -v` and then `docker compose up --build`.

## 5. Foundation validation checklist

- `docker compose config` succeeds.
- PostgreSQL and Redis become healthy.
- API `/api/v1/health` returns HTTP 200.
- API `/api/v1/health/dependencies` returns HTTP 200 and both dependencies are `ok`.
- Frontend loads and displays dependency status.
- PostgreSQL contains the expected tables.
- `pytest` passes for the API health contract.

The authoring environment for this ZIP did not have Docker installed, so the container startup/integration checks must be run on your machine before Phase 1 is considered fully validated. Static Python and frontend configuration checks were run while packaging this scaffold.

## Current scope

The API only exposes health endpoints. There is intentionally no event ingestion route or worker yet. Next, validate this foundation locally; then implement a single event type end-to-end before expanding the event catalogue.

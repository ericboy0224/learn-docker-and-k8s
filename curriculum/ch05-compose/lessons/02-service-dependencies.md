# Lesson 5.2: Service Dependencies

> "The backend keeps crashing on startup. It's trying to connect to Postgres before Postgres is even done initializing. I've added `sleep 5` to the start script. Do not tell Marcus."
> — Sarah, commit message, 11:23 PM

---

## The Startup Race Condition

Here is a real problem that catches every team working with Docker Compose for the first time.

You add `depends_on`:

```yaml
services:
  backend:
    build: ./backend
    depends_on:
      - postgres

  postgres:
    image: postgres:16-alpine
```

You run `docker compose up`. Postgres starts first, then the backend. Everything looks fine. Then the backend crashes:

```
Error: connect ECONNREFUSED 172.18.0.2:5432
```

What happened? `depends_on` only waits for the container to *start* — not for the service inside the container to be *ready*. The Postgres container started. The Postgres database process is still initializing, running its first-time setup, creating the data directory. The backend connected too early.

This is the startup race condition. `sleep 5` is not the answer (what if the host is slow? what if Postgres takes 10 seconds?). Health checks are the answer.

---

## `depends_on` — Basic vs. Condition

### Basic `depends_on`

```yaml
services:
  backend:
    depends_on:
      - postgres
      - redis
```

This tells Compose: start `postgres` and `redis` before starting `backend`. It controls *order*, not *readiness*.

### `depends_on` with Condition

```yaml
services:
  backend:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started    # same as basic depends_on
```

The `condition: service_healthy` tells Compose: do not start `backend` until `postgres` reports as healthy. But for Compose to know whether Postgres is healthy, you need to define a health check on the Postgres service.

There are three condition values:

| Condition | Meaning |
|-----------|---------|
| `service_started` | Container has started (default — same as basic depends_on) |
| `service_healthy` | Health check is passing |
| `service_completed_successfully` | Container exited with code 0 (for init/migration jobs) |

---

## Health Checks

A health check is a command Compose (and Docker) runs periodically inside the container to determine if the service is actually ready to accept work.

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: supersecret
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
```

### Health Check Properties

**`test`** — The command to run. There are three forms:

```yaml
# Form 1: Shell string (runs through /bin/sh -c)
test: "pg_isready -U brew"

# Form 2: Explicit exec array (no shell — more reliable)
test: ["CMD", "pg_isready", "-U", "brew"]

# Form 3: Shell exec array (equivalent to Form 1 but explicit)
test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]

# Disable a health check inherited from the base image:
test: ["NONE"]
```

Use `CMD-SHELL` when you need shell features (pipes, redirects). Use `CMD` when you have a simple command with arguments and want to avoid shell interpretation.

**`interval`** — How often to run the health check. Default: `30s`. During development, `5s` is more responsive.

**`timeout`** — How long to wait for the command to return. If it takes longer, the check is considered failed. Default: `30s`.

**`retries`** — How many consecutive failures before the container is marked as `unhealthy`. Default: `3`.

**`start_period`** — A grace period after startup during which failures do not count toward the `retries` limit. This gives slow-starting services time to initialize without immediately being marked unhealthy. Default: `0s`.

### Health Check States

A container with a health check moves through these states:

```
starting  →  healthy
           ↘  unhealthy
```

- **starting** — Within the `start_period`, or waiting for the first check to run
- **healthy** — Last check passed
- **unhealthy** — Failed `retries` consecutive checks

You can see the health status with:

```bash
docker compose ps
docker inspect learn-ch05-postgres-1 --format '{{.State.Health.Status}}'
```

---

## Putting It Together — A Complete Example

Here is the NoCappuccino backend waiting for Postgres to be genuinely ready:

```yaml
name: learn-ch05

services:

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: cloudbrew
      POSTGRES_USER: brew
      POSTGRES_PASSWORD: supersecret
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U brew -d cloudbrew"]
      interval: 5s
      timeout: 5s
      retries: 5
      start_period: 10s
    labels:
      app: learn-docker-k8s
      chapter: ch05

  redis:
    image: redis:7-alpine
    networks:
      - app-net
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    labels:
      app: learn-docker-k8s
      chapter: ch05

  backend:
    build: ./backend
    environment:
      DATABASE_URL: postgres://brew:supersecret@postgres:5432/cloudbrew
      REDIS_URL: redis://redis:6379
      PORT: "3000"
    ports:
      - "3000:3000"
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    labels:
      app: learn-docker-k8s
      chapter: ch05

  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    networks:
      - app-net
    depends_on:
      - backend
    labels:
      app: learn-docker-k8s
      chapter: ch05

networks:
  app-net:
    labels:
      app: learn-docker-k8s
      chapter: ch05

volumes:
  db-data:
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

Now when you run `docker compose up`, the sequence is:

1. Postgres and Redis start simultaneously (no dependency between them)
2. Compose repeatedly runs `pg_isready` and `redis-cli ping` every 5 seconds
3. Once both pass their health checks, the backend is allowed to start
4. Once the backend container starts (not healthy, just started), the frontend starts

---

## Real-World Health Check Examples

### Postgres — `pg_isready`

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
  interval: 5s
  timeout: 5s
  retries: 5
  start_period: 10s
```

`pg_isready` is a built-in Postgres utility that checks if the server is ready to accept connections. It's the right tool for this job — it speaks the Postgres protocol, not just TCP.

### Redis — `redis-cli ping`

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 5s
  timeout: 3s
  retries: 5
```

Redis responds to `PING` with `PONG` when healthy. `redis-cli` is included in the official Redis image.

### HTTP API — `curl`

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:3000/health || exit 1"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 15s
```

For HTTP services, a `/health` endpoint that returns `200 OK` is a common pattern. The `|| exit 1` ensures that if `curl` is not installed or fails, the check fails explicitly.

### MySQL / MariaDB — `mysqladmin`

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
  interval: 5s
  timeout: 5s
  retries: 5
```

---

## The `service_completed_successfully` Condition

Sometimes you need a container to run a one-time task (like running database migrations) before your application starts. This is where `service_completed_successfully` comes in.

```yaml
services:

  db-migrate:
    build: ./backend
    command: npm run migrate
    environment:
      DATABASE_URL: postgres://brew:supersecret@postgres:5432/cloudbrew
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy

  backend:
    build: ./backend
    depends_on:
      db-migrate:
        condition: service_completed_successfully
      postgres:
        condition: service_healthy
```

This pattern ensures:
1. Postgres is ready
2. Migrations run successfully
3. Backend starts only after migrations complete

---

## Why Not Just Use `sleep`?

The `sleep` approach is tempting because it's simple:

```bash
# In your Dockerfile CMD or entrypoint:
sleep 5 && node server.js
```

The problems:

1. **Fragile:** On a slow machine or under load, 5 seconds might not be enough. On a fast machine, you're wasting 5 seconds every startup.
2. **Unreliable:** Postgres might be "up" (accepting TCP connections) but still initializing and not accepting queries. The sleep doesn't tell you when it's *actually ready*.
3. **Compound delays:** With 4 services, staggered sleeps add up. Health checks let services start as soon as they're ready — not after an arbitrary wait.
4. **Misleading:** Sleep hides the real problem instead of surfacing it clearly. Health checks make the dependency explicit and observable.

The correct solution is always a proper health check.

---

## Summary

- `depends_on` (basic) controls startup order but does not wait for readiness
- `depends_on` with `condition: service_healthy` waits for health checks to pass
- Health checks run a command periodically; the container is `healthy` when it passes
- The five health check properties: `test`, `interval`, `timeout`, `retries`, `start_period`
- Use `pg_isready` for Postgres, `redis-cli ping` for Redis, `curl` for HTTP services
- `service_completed_successfully` is useful for database migrations and one-time init tasks
- Never use `sleep` as a substitute for a proper health check

Next: your compose file has `POSTGRES_PASSWORD: supersecret` in plain text. Time to fix that.

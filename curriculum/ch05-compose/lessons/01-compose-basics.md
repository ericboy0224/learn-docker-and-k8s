# Lesson 5.1: Compose Basics

> "Every time I onboard a new dev, I feel like I'm handing someone a 47-step IKEA manual with no pictures. There has to be a better way."
> — Sarah

---

## The Problem with `docker run`

Let's count what it takes to start NoCappuccino's stack manually, right now.

First, create the network:
```bash
docker network create \
  --label app=learn-docker-k8s \
  --label chapter=ch05 \
  learn-ch05-app-net
```

Then start Postgres:
```bash
docker run -d \
  --name learn-ch05-postgres \
  --network learn-ch05-app-net \
  --label app=learn-docker-k8s \
  --label chapter=ch05 \
  -e POSTGRES_DB=cloudbrew \
  -e POSTGRES_USER=brew \
  -e POSTGRES_PASSWORD=supersecret \
  -v learn-ch05-db-data:/var/lib/postgresql/data \
  postgres:16-alpine
```

Then Redis:
```bash
docker run -d \
  --name learn-ch05-redis \
  --network learn-ch05-app-net \
  --label app=learn-docker-k8s \
  --label chapter=ch05 \
  redis:7-alpine
```

Then the backend (but wait — did Postgres finish initializing? Better add a sleep...):
```bash
sleep 5
docker run -d \
  --name learn-ch05-backend \
  --network learn-ch05-app-net \
  --label app=learn-docker-k8s \
  --label chapter=ch05 \
  -e DATABASE_URL=postgres://brew:supersecret@learn-ch05-postgres:5432/cloudbrew \
  -e REDIS_URL=redis://learn-ch05-redis:6379 \
  -p 3000:3000 \
  learn-ch05-backend:latest
```

Then the frontend:
```bash
docker run -d \
  --name learn-ch05-frontend \
  --network learn-ch05-app-net \
  --label app=learn-docker-k8s \
  --label chapter=ch05 \
  -p 8080:80 \
  learn-ch05-frontend:latest
```

That's 5 commands. And we didn't even add the mail service, handle the build step, set up volumes with labels, or document any of this for the next person.

Docker Compose solves this entirely.

---

## What Is Docker Compose?

Docker Compose is a tool included with Docker Desktop (and installable separately on Linux) that lets you define your entire multi-container application in a single YAML file called `docker-compose.yml`.

Instead of 5 commands, you run one:

```bash
docker compose up -d
```

And to tear everything down:

```bash
docker compose down
```

The `docker-compose.yml` file is both the instructions and the documentation. It lives in your repository alongside your code. When a new developer clones the repo, everything they need to know about running the stack locally is right there.

---

## Anatomy of a `docker-compose.yml`

A Compose file has three top-level keys:

```yaml
services:   # The containers you want to run
networks:   # The networks connecting them
volumes:    # The persistent storage
```

Here is the full NoCappuccino stack as a Compose file:

```yaml
# docker-compose.yml

name: learn-ch05                          # The project name (prefixes all resource names)

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
    labels:
      app: learn-docker-k8s
      chapter: ch05

  redis:
    image: redis:7-alpine
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      chapter: ch05

  backend:
    build: ./backend                      # Build from ./backend/Dockerfile
    environment:
      DATABASE_URL: postgres://brew:supersecret@postgres:5432/cloudbrew
      REDIS_URL: redis://redis:6379
    ports:
      - "3000:3000"
    networks:
      - app-net
    labels:
      app: learn-docker-k8s
      chapter: ch05

  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    networks:
      - app-net
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

Notice what happened to those service hostnames. In the `DATABASE_URL` for the backend, the host is just `postgres` — the service name. Docker Compose automatically creates a user-defined network with DNS resolution for all services. Just like you learned in Chapter 4, containers can find each other by name. Compose sets this up for free.

---

## YAML Syntax Quick Reference

Docker Compose files are written in YAML (YAML Ain't Markup Language). A few rules to know:

**Indentation matters.** YAML uses spaces (not tabs) for nesting. Two spaces per level is the convention.

```yaml
services:        # top level
  postgres:      # 2 spaces — a service
    image: ...   # 4 spaces — a property of that service
```

**Strings with special characters need quotes:**
```yaml
# This would break YAML parsing:
password: p@ss:word!

# This is safe:
password: "p@ss:word!"
```

**Lists use dashes:**
```yaml
ports:
  - "3000:3000"
  - "3001:3001"
```

**Maps use key: value:**
```yaml
environment:
  NODE_ENV: production
  PORT: "3000"
```

**Environment variables as a list (alternative syntax):**
```yaml
environment:
  - NODE_ENV=production
  - PORT=3000
```

Both formats are valid. The map format (`key: value`) is generally more readable.

---

## The Three Top-Level Keys

### `services`

Each entry under `services` is a container. The key is the service name, which also becomes the DNS hostname on the network.

Common service properties:

| Property | Purpose | Example |
|----------|---------|---------|
| `image` | Use a pre-built image | `image: redis:7-alpine` |
| `build` | Build from a Dockerfile | `build: ./backend` |
| `ports` | Map host:container ports | `ports: ["3000:3000"]` |
| `environment` | Set environment variables | `environment: {NODE_ENV: prod}` |
| `volumes` | Mount volumes or bind mounts | `volumes: ["db-data:/data"]` |
| `networks` | Which networks to join | `networks: [app-net]` |
| `depends_on` | Start order (more in Lesson 2) | `depends_on: [postgres]` |
| `restart` | Restart policy | `restart: unless-stopped` |
| `labels` | Docker labels | `labels: {app: myapp}` |

### `networks`

Define custom networks here. If you don't define any networks, Compose creates a default network for all services automatically. Defining explicitly gives you control and lets you add labels.

```yaml
networks:
  app-net:
    driver: bridge        # default — usually omit this
    labels:
      app: learn-docker-k8s
```

### `volumes`

Named volumes must be declared here to exist. Bind mounts (absolute host paths) do not need to be declared.

```yaml
volumes:
  db-data:               # named volume — Docker manages the storage location
    labels:
      app: learn-docker-k8s
```

---

## Core Commands

### `docker compose up`

Starts all services defined in the Compose file. Builds images if they don't exist yet.

```bash
docker compose up           # runs in the foreground, streams all logs
docker compose up -d        # detached mode — runs in background
docker compose up --build   # forces a rebuild of all built images before starting
docker compose up backend   # starts only the 'backend' service (and its dependencies)
```

The `-d` flag (detached) is what you'll use most of the time. Without it, `Ctrl+C` stops everything.

The `--build` flag is critical when you've changed your code and need the image to be rebuilt. Without it, Compose uses the cached image.

### `docker compose down`

Stops and removes all containers, networks, and default resources.

```bash
docker compose down           # stops containers and removes them + networks
docker compose down -v        # also removes named volumes (your data!)
docker compose down --rmi all # also removes built images
```

**Warning:** `docker compose down -v` deletes your volumes. Your database data is gone. Use this intentionally during cleanup, not by accident.

### `docker compose ps`

Shows the status of all services.

```bash
$ docker compose ps
NAME                    IMAGE               COMMAND             SERVICE    STATUS     PORTS
learn-ch05-frontend-1   learn-ch05-frontend nginx -g...         frontend   running    0.0.0.0:8080->80/tcp
learn-ch05-backend-1    learn-ch05-backend  node server.js      backend    running    0.0.0.0:3000->3000/tcp
learn-ch05-redis-1      redis:7-alpine      redis-server        redis      running
learn-ch05-postgres-1   postgres:16-alpine  docker-entry...     postgres   running
```

### `docker compose logs`

View output from your services.

```bash
docker compose logs           # all services, all history
docker compose logs -f        # follow (stream new logs)
docker compose logs backend   # only the backend service
docker compose logs -f --tail=50 backend   # last 50 lines, then follow
```

### Other Useful Commands

```bash
docker compose restart backend    # restart a specific service
docker compose stop               # stop containers without removing them
docker compose start              # start stopped containers
docker compose exec backend sh    # open a shell inside a running service
docker compose run backend npm test  # run a one-off command in a new container
docker compose config             # validate and print the resolved Compose file
```

---

## Restart Policies

What happens when a container crashes? The `restart` property controls this.

| Policy | Behavior |
|--------|---------|
| `no` | Never restart (default) |
| `always` | Always restart, even after `docker compose down` and re-up |
| `on-failure` | Restart only if the container exits with a non-zero code |
| `unless-stopped` | Restart always, except when manually stopped |

For development, `unless-stopped` is usually what you want for databases and caches:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
```

For application services, `on-failure` can be useful during development to surface bugs — if the app keeps crashing, you want it to stop crashing (not loop forever).

---

## How Compose Names Resources

When you run `docker compose up`, Compose names resources using a pattern:

```
{project-name}_{service-name}_{instance-number}
```

The project name defaults to the directory name, but you can set it explicitly with the `name:` key at the top of the file (as in our example above) or with the `-p` flag:

```bash
docker compose -p learn-ch05 up -d
```

Setting `name: learn-ch05` in the file ensures all resources get the `learn-ch05-` prefix regardless of which directory the file is in. This is important for our game's naming conventions.

---

## The `build` Property in Detail

When you use `build:` instead of `image:`, Compose builds a Docker image from a Dockerfile.

```yaml
services:
  backend:
    build: ./backend              # shorthand: path to directory containing Dockerfile
```

Or with more control:

```yaml
services:
  backend:
    build:
      context: ./backend          # build context (which directory to send to Docker)
      dockerfile: Dockerfile.dev  # use a specific Dockerfile name
      args:
        NODE_ENV: development      # build arguments (available during build only)
```

The built image is tagged automatically as `{project-name}-{service-name}`.

---

## Summary

- Docker Compose turns a pile of `docker run` commands into a single YAML file
- The three top-level keys are `services`, `networks`, and `volumes`
- Service names become DNS hostnames — containers find each other by service name
- `docker compose up -d` starts everything; `docker compose down` stops and removes it
- Use `--build` to force a rebuild when your code changes
- Restart policies control what happens when a container crashes
- The `name:` key controls the project name prefix on all resources

Next up: your Compose file starts everything at once, but some services need to wait for others. The backend shouldn't start until Postgres is ready. Let's fix that.

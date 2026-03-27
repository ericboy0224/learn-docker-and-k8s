# Lesson 5.3: Environment Variables and Secrets

> "I just found our database password in a public GitHub repo. Someone committed the docker-compose.yml. That password has been live for four months. I need a very strong coffee and a very long conversation with the team."
> — Sarah, 2:14 PM, incident postmortem notes

---

## The Secret Sprawl Problem

It starts innocently. You need to tell the backend what the database password is, so you put it directly in the Compose file:

```yaml
environment:
  POSTGRES_PASSWORD: supersecret
  DATABASE_URL: postgres://brew:supersecret@postgres:5432/cloudbrew
```

Then the Compose file goes into the repository. The repository eventually becomes public — or gets accessed by someone who shouldn't have those credentials. Now you have a secret sprawl incident.

This is not a hypothetical. It happens constantly, at companies of all sizes. The fix is to separate configuration from code.

---

## Three Ways to Set Environment Variables in Compose

### Method 1: Inline in the Compose file

```yaml
services:
  backend:
    environment:
      NODE_ENV: production
      PORT: "3000"
      DATABASE_URL: postgres://brew:supersecret@postgres:5432/cloudbrew
```

**When to use:** Non-secret configuration that is fine to commit. `NODE_ENV`, `PORT`, feature flags — these are fine inline. Passwords, API keys, tokens — never.

### Method 2: The `.env` file

Create a file called `.env` in the same directory as your `docker-compose.yml`:

```bash
# .env
POSTGRES_PASSWORD=supersecret
POSTGRES_USER=brew
POSTGRES_DB=cloudbrew
DATABASE_URL=postgres://brew:supersecret@postgres:5432/cloudbrew
JWT_SECRET=my-jwt-secret-goes-here
```

Then reference the variables in your Compose file with `${VARIABLE_NAME}`:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

  backend:
    build: ./backend
    environment:
      DATABASE_URL: ${DATABASE_URL}
      JWT_SECRET: ${JWT_SECRET}
```

Docker Compose automatically loads `.env` from the project directory. You do not need to specify it explicitly.

**Critical step:** Add `.env` to `.gitignore`. Never commit it.

```bash
# .gitignore
.env
.env.local
.env.*.local
```

Provide a `.env.example` (or `.env.template`) file instead — a copy with placeholder values that *is* safe to commit. New developers copy it and fill in the real values.

```bash
# .env.example  — safe to commit, shows what's needed
POSTGRES_PASSWORD=change-me
POSTGRES_USER=brew
POSTGRES_DB=cloudbrew
DATABASE_URL=postgres://brew:change-me@postgres:5432/cloudbrew
JWT_SECRET=change-me
```

### Method 3: The `env_file` property

If you want to use a differently-named env file, or separate env files per service, use `env_file`:

```yaml
services:
  backend:
    env_file:
      - .env               # shared vars
      - .env.backend       # backend-specific vars
```

The variables are loaded in order. If both files define the same variable, the last file wins.

---

## Variable Precedence

When the same variable is defined in multiple places, this is the resolution order (highest wins):

1. **Shell environment** — variables already set in the shell running `docker compose`
2. **`--env-file` flag** — file specified on the command line: `docker compose --env-file .env.prod up`
3. **`.env` file** — the default file in the project directory
4. **`environment:` key** — values defined inline in the Compose file
5. **`env_file:` key** — files listed under the service

> **Two contexts, one precedence list.** Items 1–3 above control *YAML variable substitution* — they determine what value Compose substitutes when it reads `${VARIABLE_NAME}` in your `docker-compose.yml`. Items 4–5 (`environment:` and `env_file:`) define variables injected directly into the container's environment at runtime. In practice the distinction matters when the same variable name is set at both levels: a shell export will override a `${VAR}` substitution in YAML, but an explicit `environment:` key in the Compose file can still set a different value inside the container. When in doubt, keep secrets in `.env` and reference them via `${VAR}` throughout.

This means you can override any value for a specific deployment without touching the Compose file:

```bash
# Override for a local test run
POSTGRES_PASSWORD=localtest docker compose up -d
```

Or use a separate env file for different environments:

```bash
docker compose --env-file .env.staging up -d
docker compose --env-file .env.prod up -d
```

---

## Profiles: One Compose File for Multiple Environments

Profiles let you define services that are only started when you explicitly ask for them. This is perfect for tools that developers need locally but should never run in production.

```yaml
services:

  postgres:
    image: postgres:16-alpine
    # No profile — always starts
    ...

  backend:
    build: ./backend
    # No profile — always starts
    ...

  adminer:
    image: adminer                  # Database web UI
    ports:
      - "8081:8080"
    networks:
      - app-net
    profiles:
      - dev                         # Only starts with --profile dev
    labels:
      app: learn-docker-k8s
      chapter: ch05

  test-runner:
    build: ./backend
    command: npm test
    environment:
      DATABASE_URL: ${DATABASE_URL}
      NODE_ENV: test
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy
    profiles:
      - test                        # Only starts with --profile test
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

Now:

```bash
# Start just the core stack (postgres + backend)
docker compose up -d

# Start core + the database UI (for local development)
docker compose --profile dev up -d

# Start core + the test runner
docker compose --profile test up

# Start everything
docker compose --profile dev --profile test up -d
```

Services without a profile always start. Services with a profile only start when that profile is activated.

---

## Secrets Best Practices

### The Rules

1. **Never hardcode secrets in `docker-compose.yml`**
2. **Never commit `.env` files containing real credentials**
3. **Always provide `.env.example` so developers know what to set up**
4. **Rotate credentials if they are ever accidentally committed** — even for a moment

### Docker Secrets (Swarm-style)

Docker also has a first-class `secrets` mechanism. While Docker Swarm is out of scope for this chapter, it is worth knowing that Compose supports secrets in a simplified form using local files:

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt   # a file on your host, NOT committed
```

When using `POSTGRES_PASSWORD_FILE`, Postgres reads the password from the file path rather than an environment variable. This keeps the actual credential out of the process environment (which can be inspected with `docker inspect`).

The secrets file approach is more secure than `.env` for high-sensitivity credentials, but for local development, a well-managed `.env` with a good `.gitignore` is the pragmatic choice.

### Inspecting What's Exposed

Want to see what environment variables are visible to a running container?

```bash
docker inspect learn-ch05-backend-1 --format '{{json .Config.Env}}' | python3 -m json.tool
```

If your passwords are in there, anyone with Docker access can see them. This is another reason to prefer the `_FILE` pattern for highly sensitive credentials in production.

---

## A Complete Secure Setup

Here is the full picture for a secure NoCappuccino Compose file:

**`.env.example`** (safe to commit):
```bash
# Copy this to .env and fill in real values
POSTGRES_DB=cloudbrew
POSTGRES_USER=brew
POSTGRES_PASSWORD=change-me
DATABASE_URL=postgres://brew:change-me@postgres:5432/cloudbrew
REDIS_URL=redis://redis:6379
JWT_SECRET=change-me-to-a-random-string
MAIL_API_KEY=change-me
```

**`.env`** (never committed — add to `.gitignore`):
```bash
POSTGRES_DB=cloudbrew
POSTGRES_USER=brew
POSTGRES_PASSWORD=hunter2
DATABASE_URL=postgres://brew:hunter2@postgres:5432/cloudbrew
REDIS_URL=redis://redis:6379
JWT_SECRET=xK3p9mN2qR7sT0vY4wZ6aB8cD1eF5gH
MAIL_API_KEY=SG.xxxxxxxxxxxxxxxxxxx
```

**`docker-compose.yml`** (safe to commit — no secrets inline):
```yaml
name: learn-ch05

services:

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - app-net
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
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
      DATABASE_URL: ${DATABASE_URL}
      REDIS_URL: ${REDIS_URL}
      JWT_SECRET: ${JWT_SECRET}
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

  adminer:
    image: adminer
    ports:
      - "8081:8080"
    networks:
      - app-net
    profiles:
      - dev
    labels:
      app: learn-docker-k8s
      chapter: ch05

  test-runner:
    build: ./backend
    command: npm test
    environment:
      DATABASE_URL: ${DATABASE_URL}
      NODE_ENV: test
    networks:
      - app-net
    depends_on:
      postgres:
        condition: service_healthy
    profiles:
      - test
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

This file can go directly into the repository. No secrets anywhere.

---

## Summary

- Use `.env` files to keep secrets out of `docker-compose.yml`
- Always add `.env` to `.gitignore` and provide `.env.example` instead
- Reference variables with `${VARIABLE_NAME}` syntax in the Compose file
- Variable precedence (highest to lowest): shell → `--env-file` flag → `.env` → `environment:` → `env_file:`
- Use `profiles:` to define services that only start in specific environments
- Activate profiles with `docker compose --profile dev up -d`
- For production, consider the `_FILE` environment variable pattern with Docker secrets
- If a secret ever gets committed, rotate it immediately — removing it from history is not enough

You now have everything you need to write a complete, secure, properly-ordered Docker Compose setup. Time to build one.

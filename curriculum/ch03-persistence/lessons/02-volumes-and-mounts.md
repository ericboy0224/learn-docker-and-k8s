# Lesson 02: Volumes and Mounts

> "There are three ways to give a container persistent storage. Knowing when to use each one is half the job."
> — Sarah, NoCappuccino DevOps

---

## The Three Types

Docker gives you three mechanisms to mount storage into a container. They look similar from the inside of the container, but they are very different animals.

```
 Host filesystem                    Container
 ─────────────────                  ──────────────────
 /var/lib/docker/volumes/  ──────►  Named Volume
 /home/eric/my-project/    ──────►  Bind Mount
 (in memory, no host path) ──────►  tmpfs Mount
```

Each one has a distinct purpose. Let's go through them.

---

## 1. Named Volumes

A **named volume** is a chunk of storage that Docker creates and manages for you. You give it a name, Docker stores it on the host (under `/var/lib/docker/volumes/` on Linux), and you mount it into containers. Docker handles the details.

### Creating a named volume

```bash
docker volume create \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  learn-ch03-db-data
```

### Listing volumes

```bash
docker volume ls --filter "label=app=learn-docker-k8s"
```

Output:
```
DRIVER    VOLUME NAME
local     learn-ch03-db-data
```

### Inspecting a volume

```bash
docker volume inspect learn-ch03-db-data
```

Output:
```json
[
    {
        "CreatedAt": "2026-03-26T10:00:00Z",
        "Driver": "local",
        "Labels": {
            "app": "learn-docker-k8s",
            "chapter": "ch03"
        },
        "Mountpoint": "/var/lib/docker/volumes/learn-ch03-db-data/_data",
        "Name": "learn-ch03-db-data",
        "Options": {},
        "Scope": "local"
    }
]
```

The `Mountpoint` is where Docker stores the actual data on your host. On macOS and Windows, Docker runs inside a Linux VM — the path shown is inside that VM, not directly on your Mac's filesystem. That is why named volumes are the preferred way to persist container data on those platforms.

### Using a named volume with `-v`

```bash
docker run -d \
  --name learn-ch03-mysql \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  -e MYSQL_ROOT_PASSWORD=cloudbrewsecret \
  -e MYSQL_DATABASE=preferences \
  -v learn-ch03-db-data:/var/lib/mysql \
  mysql:8.0
```

The `-v learn-ch03-db-data:/var/lib/mysql` flag tells Docker: mount the named volume `learn-ch03-db-data` at the path `/var/lib/mysql` inside the container. MySQL writes all its database files there. When this container is deleted and a new one is created with the same volume, the data is exactly where MySQL expects it.

### Anonymous volumes

If you use `-v /var/lib/mysql` (no name, just a path), Docker creates an **anonymous volume** — a named volume with a generated UUID as its name. Anonymous volumes work the same way, but they are much harder to manage because the name is meaningless. Avoid them for data you care about.

```bash
# This creates an anonymous volume — avoid for important data
docker run -d -v /var/lib/mysql mysql:8.0

# This creates a named volume — use this instead
docker run -d -v learn-ch03-db-data:/var/lib/mysql mysql:8.0
```

### When to use named volumes

- **Production databases** (MySQL, PostgreSQL, MongoDB, Redis)
- **Any data that must outlive the container**
- **Environments where you cannot guarantee the host path** (production servers, CI)
- Anywhere you want Docker to manage the storage lifecycle

---

## 2. Bind Mounts

A **bind mount** maps a specific directory on your host machine directly into the container. The container sees the host files in real time — changes on either side are immediately reflected on the other.

```bash
docker run -d \
  --name learn-ch03-node-app \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  -v ~/my-app:/app \
  -p 3000:3000 \
  node:20-alpine node /app/index.js
```

Here, `~/my-app` on the host is mounted at `/app` inside the container. If you edit `index.js` on your host, the container sees the change instantly. This is the foundation of hot-reload development workflows.

### The `--mount` syntax (more explicit)

Docker also supports `--mount` which is more verbose but harder to misread:

```bash
docker run -d \
  --name learn-ch03-node-app \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  --mount type=bind,source=$HOME/my-app,target=/app \
  -p 3000:3000 \
  node:20-alpine node /app/index.js
```

The `--mount` flag is recommended for new scripts because the intent is explicit. The `-v` flag is common in examples and documentation — you will see both.

### When to use bind mounts

- **Local development** — edit code on your host, app reloads inside the container
- **Injecting config files** at a known host path
- **Accessing host system data** (e.g., mounting `/var/run/docker.sock` for Docker-in-Docker tools)
- **Build pipelines** where you want to share source code into a build container

### What to avoid with bind mounts

- Do not use bind mounts for production databases — the data is tied to a specific host path and machine
- Be careful with permissions: the container process runs as a specific user (often root or a custom UID), and the mounted files belong to your host user — this can cause permission errors (Challenge 03 is all about this)
- Do not mount your entire home directory or root — only mount what the container needs

---

## 3. tmpfs Mounts

A **tmpfs mount** lives entirely in the host's memory. Nothing is written to disk. When the container stops, the data is gone — even faster than a regular writable layer.

```bash
docker run -d \
  --name learn-ch03-secret-cache \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  --mount type=tmpfs,target=/run/secrets \
  nginx:alpine
```

### When to use tmpfs

- **Sensitive, short-lived data** that should never touch disk: session tokens, decrypted credentials, one-time tokens
- **High-performance scratch space**: tmpfs reads and writes at memory speed, much faster than any disk
- **Ephemeral caches** that should not persist between runs

### Limitations

- tmpfs is not available on Windows containers
- The data is gone when the container stops — this is intentional
- Size is limited by available RAM; use `tmpfs-size` option to cap it:

```bash
--mount type=tmpfs,target=/run/secrets,tmpfs-size=64m
```

---

## Side-by-Side Comparison

| Feature | Named Volume | Bind Mount | tmpfs |
|---------|-------------|------------|-------|
| Managed by Docker | Yes | No | Yes |
| Data persists after `docker rm` | Yes | Yes (on host) | No |
| Host path required | No | Yes | No |
| Works on macOS/Windows | Yes | Yes | No (Linux only) |
| Performance | Good | Good (same as host) | Excellent |
| Use case | Production data | Dev workflows | Sensitive data, caches |
| Visible in `docker volume ls` | Yes | No | No |

---

## The `-v` Shorthand Cheat Sheet

Docker infers the mount type from the format of the `-v` argument:

```bash
# Named volume (starts with a name)
-v learn-ch03-db-data:/var/lib/mysql

# Bind mount (starts with / or ./)
-v ~/my-app:/app
-v ./my-app:/app

# Anonymous volume (just a path)
-v /var/lib/mysql
```

---

## Removing Volumes

Named volumes are **not deleted** when you remove a container. You must delete them explicitly:

```bash
# Remove a specific volume
docker volume rm learn-ch03-db-data

# Remove all volumes not attached to any container (dangerous — read the warning)
docker volume prune --filter "label=app=learn-docker-k8s"
```

This is intentional — Docker protects your data from accidental deletion. But it also means orphaned volumes accumulate over time. The `docker volume prune` command cleans up volumes with no associated containers. Always use label filters when running in an environment with other work.

---

## Key Takeaways

- **Named volumes**: Docker-managed, persistent, ideal for production databases and stateful services.
- **Bind mounts**: Direct host path access, ideal for local development and injecting host files.
- **tmpfs**: In-memory only, ideal for sensitive short-lived data.
- Anonymous volumes work but are hard to manage — always name your volumes.
- Volumes survive `docker rm`; tmpfs does not; the container writable layer does not.

---

## Up Next

You know the three types of mounts. Now let's talk about volume lifecycle — how volumes persist across container deletions, how to share a volume between multiple containers, and how to back up and restore your data.

**[Lesson 03: Volume Lifecycle →](03-volume-lifecycle.md)**

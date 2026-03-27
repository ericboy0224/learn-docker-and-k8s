# Lesson 03: Volume Lifecycle

> "The volume doesn't care about your container. It was there before it, and it'll be there after."
> — Sarah, NoCappuccino DevOps

---

## Volumes Outlive Containers

This is the fundamental contract of a named volume: it exists independently of any container that uses it.

Let's trace the lifecycle of the `learn-ch03-db-data` volume step by step:

```
docker volume create learn-ch03-db-data    ← Volume created (empty)
         │
         ▼
docker run -v learn-ch03-db-data:/var/lib/mysql mysql:8.0
         │                                  ← Container uses the volume
         ▼
  (write data to /var/lib/mysql inside container)
         │
         ▼
docker rm -f learn-ch03-mysql              ← Container deleted
         │
         ▼
  learn-ch03-db-data still exists          ← Volume survives
         │
         ▼
docker run -v learn-ch03-db-data:/var/lib/mysql mysql:8.0
         │                                  ← New container, same volume
         ▼
  (data is still there)                    ← Persistence confirmed
```

This is the pattern you will use in Challenge 01. The container is a temporary process. The volume is the durable storage layer.

---

## Sharing a Volume Between Containers

A single named volume can be mounted by multiple containers simultaneously. This is a powerful pattern — and also a dangerous one if you are not careful.

### Read/Write sharing

Imagine NoCappuccino's image upload service writes photos to a shared directory, and a thumbnail generator service reads from the same directory:

```bash
# Container 1: writes uploaded images
docker run -d \
  --name learn-ch03-uploader \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  -v learn-ch03-app-data:/uploads \
  nginx:alpine

# Container 2: reads from the same volume
docker run -d \
  --name learn-ch03-thumbnailer \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  -v learn-ch03-app-data:/uploads \
  alpine watch -n 5 "ls /uploads"
```

Both containers now see the same `/uploads` directory. Files written by the uploader appear immediately in the thumbnailer.

### Read-only mounts

If one container should only read from a volume, add `:ro` to the mount flag:

```bash
docker run -d \
  --name learn-ch03-reader \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  -v learn-ch03-app-data:/uploads:ro \
  alpine
```

Inside this container, `/uploads` is read-only. Any attempt to write will be denied. This is a good security practice — give each container only the access it needs.

### Caution: concurrent writes

If two containers write to the same files at the same time without coordination (locks, message queues), you can corrupt data. Volumes do not provide any locking mechanism. For databases, use replication protocols — do not share a single volume between two MySQL instances.

---

## Volume Drivers

By default, named volumes use the `local` driver — data is stored on the local filesystem of the Docker host.

For production environments with multiple hosts, you need a **volume driver** that stores data on shared or networked storage so any host can access it:

| Driver | Storage Backend | Use Case |
|--------|----------------|----------|
| `local` | Host filesystem | Development, single-host setups |
| `rexray/s3fs` | AWS S3 | Cloud-native object storage |
| `rexray/ebs` | AWS EBS | High-performance block storage |
| `azure-file` | Azure Files | Azure-hosted SMB shares |
| `nfs` | NFS server | On-prem shared storage |
| `portworx` | Portworx cluster | Enterprise Kubernetes storage |

You specify a driver when creating the volume:

```bash
docker volume create \
  --driver rexray/s3fs \
  --opt bucket=cloudbrew-uploads \
  --label app=learn-docker-k8s \
  learn-ch03-cloud-data
```

This is a topic you will revisit in Chapters 6 and 7 when we move to Kubernetes, where it becomes PersistentVolumes and StorageClasses. The concept is the same: decouple storage from compute so your data survives even when the host machine is replaced.

---

## Inspecting What Is Inside a Volume

Because volumes are managed by Docker and stored in a Docker-internal path, you cannot browse them directly (especially on macOS/Windows). The easiest way is to mount the volume into a temporary container:

```bash
docker run --rm \
  -v learn-ch03-db-data:/inspect \
  alpine ls -la /inspect
```

The `--rm` flag removes the container automatically when it exits. This pattern — spin up a temporary utility container to inspect or manipulate a volume — is very common.

---

## Backup and Restore

Volumes need backups. Here is the standard pattern.

### Backup: volume → tar archive on host

```bash
docker run --rm \
  -v learn-ch03-db-data:/source:ro \
  -v "$(pwd)":/backup \
  alpine tar czf /backup/ch03-db-backup.tar.gz -C /source .
```

What this does:
1. Mounts the production volume at `/source` (read-only — safe)
2. Mounts the current host directory at `/backup`
3. Runs `tar` to compress everything from `/source` into `/backup/ch03-db-backup.tar.gz`
4. The container exits and is removed (`--rm`)

You now have a `ch03-db-backup.tar.gz` file on your host.

### Restore: tar archive → volume

```bash
# Create the destination volume first
docker volume create \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  learn-ch03-db-restore

# Unpack the backup into it
docker run --rm \
  -v learn-ch03-db-restore:/target \
  -v "$(pwd)":/backup:ro \
  alpine tar xzf /backup/ch03-db-backup.tar.gz -C /target
```

Now `learn-ch03-db-restore` contains the restored data, ready to mount into a new container.

### Database-specific backups

For MySQL and PostgreSQL, it is better to use the database's own export tool rather than a raw filesystem copy — this gives you a consistent, portable SQL dump even while the database is running:

```bash
# MySQL logical backup
docker exec learn-ch03-mysql \
  mysqldump -u root -pcloudbrewsecret preferences > ch03-preferences-dump.sql

# Restore
docker exec -i learn-ch03-mysql \
  mysql -u root -pcloudbrewsecret preferences < ch03-preferences-dump.sql
```

A filesystem-level backup (the tar method) requires the database to be stopped for consistency — it copies the raw data files, which can be corrupted if MySQL is writing during the copy.

---

## Removing Volumes: The Right Way

Volumes are not deleted automatically. This protects data but means cleanup is manual.

```bash
# Remove a specific volume (fails if any container is using it)
docker volume rm learn-ch03-db-data

# Force removal of all volumes labeled for this course
docker volume prune --filter "label=app=learn-docker-k8s"

# List volumes that have no associated containers (candidates for cleanup)
docker volume ls -f dangling=true
```

A **dangling volume** is one with no container currently associated with it. They are safe to remove if you no longer need the data.

---

## The Lifecycle at a Glance

```
Create          Mount into container    Remove container    Inspect/backup     Delete volume
─────────       ──────────────────────  ────────────────    ──────────────     ────────────────
docker          docker run              docker rm           docker run --rm    docker volume rm
volume          -v name:/path                               -v name:/inspect
create
```

Every step is a distinct operation, and none of them implicitly triggers the others. Docker's persistence model is explicit by design.

---

## Key Takeaways

- Named volumes persist after `docker rm` — the container lifecycle and the volume lifecycle are independent.
- Multiple containers can mount the same volume. Use `:ro` for read-only access where writes are not needed.
- Concurrent writes to a shared volume require application-level coordination — volumes provide no locking.
- Volume drivers extend the `local` driver to network-attached and cloud storage — essential for multi-host production.
- Back up important volumes using a temporary Alpine container running `tar`, or use the database's own export tools for consistency.
- `docker volume prune` cleans up dangling volumes — always use label filters in shared environments.

---

## Lessons Complete

You now understand ephemeral containers, the three mount types, and how the volume lifecycle works. It is time to apply all of this hands-on.

**[Challenge 01: Survive the Restart →](../challenges/01-survive-restart.md)**

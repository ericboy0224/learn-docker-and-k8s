# Lesson 01: Ephemeral Containers

> "Dave's 'just restart it' approach finally caught up with us."
> — Sarah, NoCappuccino DevOps

---

## The Incident

Let me tell you about the Great Database Incident of 2024. (Yes, the one I have been hinting at since Chapter 1. You have earned it.)

We had a MySQL container running on a $5 DigitalOcean droplet. No volume. No backup. Just the default setup because "we'll add that later." A container restart during a routine deploy wiped three months of beta tester data. Marcus cried. Dave blamed the cloud. I knew exactly what happened — and I knew I should have stopped it.

Container data is **ephemeral**. That is not a bug. That is the design.

---

## What Actually Happens Inside a Container

When Docker runs a container from an image, it does not modify the image. Instead, it adds a thin **writable layer** on top of the read-only image layers. All filesystem changes inside the container — new files, modified configs, database records — go into that writable layer.

Here is the structure:

```
Container Writable Layer  <-- your runtime data goes here (temporary)
─────────────────────────
Image Layer 3: app code   (read-only)
Image Layer 2: npm deps   (read-only)
Image Layer 1: node:20    (read-only)
```

This stack is called a **union mount** (or overlay filesystem). On Linux, Docker uses the `overlay2` storage driver, which implements this using the kernel's OverlayFS.

When you run `docker rm` on a container, the writable layer is deleted. The image layers stay — they are shared across containers — but your runtime data is gone.

---

## Seeing It Happen

Let's prove it. In teaching mode, run these commands together:

**Step 1:** Create a file inside a container.

```bash
docker run --name learn-ch03-demo \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  alpine sh -c "mkdir -p /data && echo 'NoCappuccino secret recipe' > /data/recipe.txt && cat /data/recipe.txt"
```

Output:
```
NoCappuccino secret recipe
```

The file exists. The container exits because `sh -c` finishes.

**Step 2:** Try to read the file by starting the same container again.

```bash
docker start -ai learn-ch03-demo
```

Nothing. The command already ran — `docker start` reruns the original command. Let's be more direct:

```bash
docker run --name learn-ch03-demo2 \
  --label app=learn-docker-k8s \
  --label chapter=ch03 \
  alpine sh -c "cat /data/recipe.txt"
```

Output:
```
cat: can't open '/data/recipe.txt': No such file or directory
```

The file was written to `learn-ch03-demo`'s writable layer. `learn-ch03-demo2` is a fresh container from the same image — it has no knowledge of what the first container wrote.

**Step 3:** Now remove the first container.

```bash
docker rm learn-ch03-demo learn-ch03-demo2
```

That writable layer — and its contents — is deleted permanently.

---

## The Linux Angle: OverlayFS

At the kernel level, Docker's `overlay2` driver mounts the union filesystem with two directories:

- **lowerdir**: The read-only image layers (stacked together)
- **upperdir**: The writable layer for the running container
- **merged**: The unified view that the container process sees

You can inspect this on a Linux host:

```bash
docker inspect learn-ch03-demo --format '{{json .GraphDriver.Data}}'
```

This shows the `LowerDir`, `UpperDir`, `MergedDir`, and `WorkDir` paths that make up the overlay mount.

When the container is removed, Docker deletes the `upperdir` and `workdir` paths. The `lowerdir` paths (image layers) remain because they may be shared with other containers or images.

This is the same principle as the union filesystems you learned about in Chapter 2 when optimizing image layers — except now it applies to runtime data, not build time.

---

## What This Means For You

| Data Type | Stored In | Survives `docker rm`? |
|-----------|-----------|----------------------|
| App code (from image) | Image layers (lowerdir) | Yes |
| Config in Dockerfile | Image layers (lowerdir) | Yes |
| Runtime writes (DB records, uploads) | Container writable layer (upperdir) | **No** |
| Volume-mounted data | Docker volume (outside container) | **Yes** |

The rule is simple: **if you care about the data, it must live outside the container.**

---

## Common Misconceptions

**"But `docker stop` doesn't delete my container, so the data is safe, right?"**

Yes — until you run `docker rm`, or use `docker run --rm`, or upgrade the image and recreate the container. `docker stop` only pauses the process. The writable layer still exists. But the moment you `docker rm` (which is what you do every deploy), it is gone.

**"Can't I just `docker commit` the container to save the data?"**

Technically yes — `docker commit` bakes the writable layer into a new image. But this is a terrible practice for databases. You end up with data embedded in an image, which is not transferable, not auditable, and not how anyone should manage state. Never do this in production.

**"What about `docker restart`?"**

`docker restart` stops and starts the same container — it does *not* delete the writable layer. So data survives a restart as long as you are restarting the same container object. The problem Dave hit was that he ran `docker rm` and then `docker run` — a new container, empty writable layer.

---

## Key Takeaways

- Container storage is ephemeral: the writable layer is deleted when the container is removed.
- Docker uses OverlayFS (`overlay2` driver) to stack read-only image layers under a thin writable layer.
- Any data written inside a container at runtime (database files, uploads, logs) lives in the writable layer and will not survive `docker rm`.
- The solution is volumes and mounts — the subject of the next lesson.

---

## Up Next

Now that you understand *why* data disappears, let's look at the three ways Docker lets you attach persistent storage to a container: named volumes, bind mounts, and tmpfs.

**[Lesson 02: Volumes and Mounts →](02-volumes-and-mounts.md)**

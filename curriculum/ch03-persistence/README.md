  ___ _    ____   ___ _
 / __| |_ |__ /  / __| |_ ___ _ _ __ _ __ _ ___
| (__| ' \ |_ \ \__ \  _/ _ \ '_/ _` / _` / -_)
 \___|_||_|___/  |___/\__\___/_| \__,_\__, \___|
                                      |___/

 💾 "The Vanishing Beans"

    WITHOUT volume:            WITH volume:
    .----------.               .----------.
    |   Data   |               |   Data   |
    '----+-----'               '----+-----'
         |                          |
         v                    .-----v-----.
      (gone!) 💨              |  Volume   | <-- still here! ✅
                              '-----------'

    (@_@;) Dave: "I just restarted the database..." 😱

# Chapter 3: The Vanishing Beans

> "I added a new specialty roast to my favorites, but when the server restarted, it was gone!"
> — NoCappuccino customer support ticket #4471

## The Story

You did it. The app is containerized, the image is lean, and Marcus finally stopped complaining about deploy times. Time for a coffee break.

Then Slack lights up.

Dave: "Hey, quick question — I restarted the database container because it was acting weird. That's fine, right?"

Sarah: "...Dave, please tell me you used a volume."

Dave: "A what?"

And just like that, NoCappuccino lost three weeks of customer preference data. Every saved favorite roast, every "I hate dark roast" annotation, every carefully curated brewing profile — gone. Poof. Vanished like steam from a cup of espresso.

This is *the* classic container mistake. Containers are ephemeral by design — they are meant to be thrown away and recreated. The writable layer inside a container lives and dies with the container itself. If you store your database files there, you are building your house on sand.

Today you are going to fix that. And while you are at it, you are going to learn why Dave's approach of "just restart it" finally caught up with us — and how to make sure it never hurts us again.

---

## What You Will Learn

By the end of this chapter you will be able to:

- Explain why container storage is ephemeral and what the writable layer actually is at the filesystem level
- Create and manage Docker named volumes, bind mounts, and tmpfs mounts
- Choose the right storage type for each situation (production data vs. local dev vs. sensitive in-memory data)
- Share a volume between multiple containers
- Recover from the "I deleted the container and lost all my data" incident
- Debug permission errors that occur when volumes are mounted into containers running as non-root users

---

## Chapter Structure

### Lessons

| # | Title | Core Concept |
|---|-------|-------------|
| 01 | [Ephemeral Containers](lessons/01-ephemeral-containers.md) | The container writable layer and why data disappears |
| 02 | [Volumes and Mounts](lessons/02-volumes-and-mounts.md) | Named volumes, bind mounts, and tmpfs |
| 03 | [Volume Lifecycle](lessons/03-volume-lifecycle.md) | Persistence, sharing, backup, and restore |

### Challenges

| # | Title | Difficulty |
|---|-------|-----------|
| 01 | [Survive the Restart](challenges/01-survive-restart.md) | Beginner |
| 02 | [Dev Hot Reload](challenges/02-dev-hot-reload.md) | Beginner |
| 03 | [Permission Debug](challenges/03-permission-debug.md) | Intermediate |

---

## Prerequisites

- Chapter 1 complete (you know how to run and manage containers)
- Chapter 2 complete (you understand image layers)
- Docker installed and running on your machine

---

## Resources You Will Create

All Docker resources in this chapter use the `learn-` prefix and are labeled for safe cleanup:

| Resource | Name | Type |
|----------|------|------|
| Volume | `learn-ch03-db-data` | Named volume |
| Volume | `learn-ch03-app-logs` | Named volume |
| Container | `learn-ch03-mysql` | MySQL database |
| Container | `learn-ch03-node-app` | Node.js app |
| Image | `learn-ch03-perm-app` | Custom image |

To clean up everything after this chapter:

```bash
bash engine/cleanup.sh
```

---

## Post-Chapter Debrief

Once you complete all three challenges and `verify.sh` passes, here is your debrief:

**What you did:** You gave the database a home outside the container. Named volumes live on your Docker host's filesystem, completely independent of any container that mounts them. You can delete the container, upgrade the image, redeploy — and the data is still there, waiting.

**Why it works:** Docker volumes are managed storage objects that live under `/var/lib/docker/volumes/` on the host (on Linux). When a container mounts a volume, Docker uses a bind mount under the hood to expose that directory into the container's filesystem via the union mount. The container sees it as a normal directory. The data, however, is on the host — not in the container's writable layer.

**Real-world connection:** Every production database you will ever run in a container — MySQL, PostgreSQL, MongoDB, Redis — needs a persistent volume. Without it, the first container restart or image upgrade wipes everything. This is one of the most common mistakes in early Docker deployments.

**Interview angle:** "What is the difference between a named volume and a bind mount?" is a common Docker interview question. Named volumes are managed by Docker (better for production, portable across environments). Bind mounts are a direct host path (better for development, gives you full access to source files). Knowing *when* to use each one is what separates a beginner from someone who has actually run Docker in production.

**Pro tip:** In production, you rarely want volumes backed by the local filesystem of a single host. Look into volume drivers like `rexray`, `portworx`, or cloud-provider plugins (AWS EFS, Azure Files, GCP Persistent Disk) that let your volume survive even if the host machine dies.

---

## Cliffhanger

You mount the volume. You recreate the container. You query the database. The data is there.

Dave types in Slack: "Wait, it worked? So all you had to do was add `-v` to the command? I've been restarting servers for 10 years and nobody told me this!"

Sarah (you): "Better late than never, Dave."

But before you can finish your coffee, Marcus sends a new message: "Data is safe now. But we have a bigger problem — Demo Day is tomorrow and the frontend can't talk to the backend. Something about 'host not found'. Can someone look at this?"

You glance at the error log. `Could not resolve host: cloudbrew-api`. Of course. They are on separate networks and cannot find each other by name.

Time to learn about Docker networking.

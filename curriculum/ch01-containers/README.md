  ___ _    _ _    ___         _        _
 / __| |_ / (_)  / __|___ _ _| |_ __ _(_)_ _  ___ _ _ ___
| (__| ' \| |_  | (__/ _ \ ' \  _/ _` | | ' \/ -_) '_(_-<
 \___|_||_|_(_)  \___\___/_||_\__\__,_|_|_||_\___|_| /__/

 📦 "It Works on My Machine"

    Dave's Laptop            Staging Server
    .-------------.          .-------------.
    | Node 18  OK |          | Node 14  !! |
    | API works!  |          | API crash!  |
    '-------------'          '-------------'
       ☕ ☕ ☕                   💀 💀 💀
          \                        /
           '--- "Works on my ----'
                 machine!"

    (@_@;) Dave: "But it works on MY machine..." 😰

# Chapter 1: "It Works on My Machine"

## The Story So Far

Welcome to NoCappuccino — your first day on the job.

You've barely found the coffee bar when Dave, our CTO (currently wearing his "I ❤️ Java" shirt), slides over looking like he hasn't slept. He pulls up Slack on his phone and shows you a wall of red error logs.

> **Dave:** "The Aroma-Discovery API works perfectly on my laptop. I swear. But every time we push to staging it crashes with some Node version mismatch. I've been telling the server team to just install the right library but they keep saying 'it's not a server problem.'"

I'm Sarah — senior DevOps here at NoCappuccino. Don't mind Dave. He's great at product, but his idea of "deployment" is copy-pasting files over SSH. We're going to fix this the right way.

If the API isn't up by lunch, our first 500 coffee subscribers get a 404 instead of their morning fix. Marcus, our PM, is already asking questions. So: no pressure, but also... definitely some pressure.

Here's the deal: we're going to put Dave's app in a **container**. A container carries everything the app needs — the right version of Node, the right libraries, all of it — so it runs the same everywhere. On Dave's laptop, on staging, on a server in a data center halfway around the world.

Let's get you up to speed.

---

## What You'll Learn

By the end of this chapter you'll understand:

- What Docker containers are and why they exist
- The difference between containers and virtual machines
- How Docker images and containers relate to each other (the recipe vs. the dish)
- The core Docker CLI commands for the entire container lifecycle
- How port mapping works (why `-p 8080:80` means something specific)
- Why the "it works on my machine" problem is fundamentally an environment problem — and how containers solve it

## What You'll Build

You'll complete three hands-on challenges:

1. **Run an Nginx container** accessible at `localhost:8080`
2. **Build your own Docker image** for a simple Node.js app and run it on port 3000
3. **Debug a broken container** — figure out why a running container is unreachable and fix it

## Prerequisites

None. If you have Docker installed and running, you're ready. If you haven't done that yet, run the environment check first:

```bash
./engine/environment-check.sh
```

## Estimated Time

- Lessons: ~30 minutes
- Challenges: ~30–45 minutes
- Total: ~1 hour (faster if you have some terminal experience)

---

## Lessons

| # | Lesson | Topics |
|---|--------|--------|
| 01 | [What is Docker?](lessons/01-what-is-docker.md) | Containers vs VMs, Docker's origin, namespaces & cgroups |
| 02 | [Images and Containers](lessons/02-images-and-containers.md) | Image = recipe, layers, Docker Hub, pull & inspect |
| 03 | [Basic Commands](lessons/03-basic-commands.md) | Full container lifecycle: run, ps, stop, rm, logs, exec |

## Challenges

| # | Challenge | Goal |
|---|-----------|------|
| 01 | [Run Nginx](challenges/01-run-nginx.md) | Serve nginx on localhost:8080 |
| 02 | [Build Your First Image](challenges/02-build-first-image.md) | Dockerize a Node.js Express app |
| 03 | [Debug Port Mapping](challenges/03-debug-port.md) | Find and fix an unreachable container |

To verify your work: `bash challenges/verify.sh`

---

## Post-Chapter Debrief

Once all challenges pass, you'll have done something real: you containerized an app end-to-end. Dave's "it works on my machine" excuse officially expired.

But don't relax too long. Marcus just pinged me. Apparently our deploy takes 10 minutes because the image is nearly 2 gigabytes. We're going to have a talk about that in Chapter 2.

---

## Key Concepts Reference

| Term | One-line definition |
|------|---------------------|
| **Image** | A read-only template containing your app and all its dependencies |
| **Container** | A running instance of an image — isolated, ephemeral by default |
| **Dockerfile** | Instructions for building a custom image |
| **Docker Hub** | The public registry where official images live |
| **Port mapping** | Connecting a host port to a container port (`-p host:container`) |
| **Namespace** | Linux kernel feature that creates isolated views of system resources |
| **cgroup** | Linux kernel feature that limits CPU/memory a process can use |

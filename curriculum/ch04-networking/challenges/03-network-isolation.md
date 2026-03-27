# Challenge 3: Network Isolation

> "The demo worked. The integration worked. And then someone from the security team sent me a very uncomfortable Slack message. Apparently our frontend container has direct access to the database. That means if someone ever exploited the frontend — XSS, dependency vulnerability, whatever — they'd have a straight shot at the database. We need to fix the architecture. Now."
> — Sarah

---

## The Situation

NoCappuccino currently has three services: a frontend, a backend API, and a database. Right now, all three are on the same network. That's a security problem.

The correct architecture is a **two-tier network**:

```
[Frontend] <--frontend-net--> [Backend] <--backend-net--> [Database]
    |                                                           |
    +------- CANNOT directly reach --------+
```

- The **frontend** can talk to the **backend**
- The **backend** can talk to the **database**
- The **frontend** CANNOT directly talk to the **database**

The backend is the only service that bridges both networks.

---

## Setup

Start the three containers all on the same (wrong) network to establish the broken architecture:

```bash
# Create a single flat network (the insecure setup)
docker network create \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  learn-ch04-flat-net

# Start the database
docker run -d \
  --name learn-ch04-db \
  --network learn-ch04-flat-net \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  alpine sleep 3600

# Start the backend
docker run -d \
  --name learn-ch04-backend-iso \
  --network learn-ch04-flat-net \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  alpine sleep 3600

# Start the frontend
docker run -d \
  --name learn-ch04-frontend-iso \
  --network learn-ch04-flat-net \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  alpine sleep 3600
```

**Verify the insecure state (all three can reach each other):**

```bash
# Frontend can currently ping DB directly -- this should NOT be allowed:
docker exec learn-ch04-frontend-iso ping -c 1 learn-ch04-db
# PING learn-ch04-db: 56 data bytes
# 64 bytes from ... (currently works -- this is the problem)
```

---

## Your Goal

Reconfigure the network so that:

1. `learn-ch04-frontend-iso` can ping `learn-ch04-backend-iso` by name — **SUCCESS**
2. `learn-ch04-backend-iso` can ping `learn-ch04-db` by name — **SUCCESS**
3. `learn-ch04-frontend-iso` CANNOT reach `learn-ch04-db` by name or IP — **BLOCKED**

---

## Constraints

- Use exactly two networks: one for frontend-to-backend, one for backend-to-database
- Network names must use the `learn-ch04-` prefix
- All resources must have labels: `--label app=learn-docker-k8s --label chapter=ch04`
- The backend must bridge both networks (it needs to talk to both frontend and database)
- Do not use `--network host` or any flag that bypasses network isolation

---

## Hints

Only read these if you're stuck.

<details>
<summary>Hint 1 — General direction</summary>

Two separate networks enforce isolation because containers on different networks can't communicate by default. The key insight is that the backend needs to be on **both** networks simultaneously — Docker supports this. Think about which containers belong to which network, and which one needs to span both.

</details>

<details>
<summary>Hint 2 — Specific area</summary>

You'll need to:
1. Create two new user-defined networks (e.g., `learn-ch04-frontend-net` and `learn-ch04-backend-net`)
2. Disconnect all containers from `learn-ch04-flat-net`
3. Connect frontend and backend to `learn-ch04-frontend-net`
4. Connect backend and db to `learn-ch04-backend-net`

The backend ends up on two networks at once. Use `docker network connect` to attach a running container to an additional network.

</details>

<details>
<summary>Hint 3 — Near answer</summary>

Here's the full flow (without the exact commands — you can figure those out):

1. `docker network create learn-ch04-frontend-net` (with labels)
2. `docker network create learn-ch04-backend-net` (with labels)
3. Disconnect all three containers from `learn-ch04-flat-net`
4. Connect `learn-ch04-frontend-iso` to `learn-ch04-frontend-net`
5. Connect `learn-ch04-backend-iso` to `learn-ch04-frontend-net`
6. Connect `learn-ch04-backend-iso` to `learn-ch04-backend-net` (second network!)
7. Connect `learn-ch04-db` to `learn-ch04-backend-net`

After this:
- frontend and backend share `frontend-net` → they can ping each other
- backend and db share `backend-net` → they can ping each other
- frontend and db share NO network → they cannot communicate

</details>

---

## Verify

Once you think you've solved it, run the chapter's verify script:

```bash
bash curriculum/ch04-networking/challenges/verify.sh
```

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You split a flat network into two separate networks — a frontend/backend network and a backend/database network. The backend bridges both. The frontend has no path to the database.

**Why it works:**
Docker enforces network isolation at the Linux level. Containers on different networks are in different Layer 2 segments with no routing between them by default. When you put the frontend and database on separate networks with no overlap, there's no path for packets to travel between them — not even by IP. It's not a firewall rule; it's a routing gap.

**Real-world connection:**
This two-tier (or three-tier: public/app/data) network model is standard in production. In Kubernetes, it maps to Network Policies. In AWS, it maps to VPC subnets and security groups. In every case, the principle is the same: least-privilege networking. Services should only be able to reach what they need to reach.

**Interview angle:**
"How would you prevent a frontend container from accessing the database directly in Docker?" — Create separate networks. The backend connects to both; the frontend connects only to the frontend-backend network. This answer demonstrates understanding of Docker's network isolation model.

**Pro tip:**
You can verify a container's networks with:
```bash
docker inspect learn-ch04-backend-iso \
  --format '{{range $net, $cfg := .NetworkSettings.Networks}}{{$net}} -> {{$cfg.IPAddress}}{{"\n"}}{{end}}'
```
A container on two networks will show two entries — one IP per network.

</details>

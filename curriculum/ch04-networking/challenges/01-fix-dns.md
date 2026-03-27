# Challenge 1: Fix the DNS

> "Okay, here's the situation. I spun up the frontend and backend for the demo — but I put them on the default bridge. Classic mistake, I know. The frontend is throwing 'host not found' when it tries to reach the backend by name. Demo is in 90 minutes. Fix it."
> — Sarah

---

## The Situation

Two containers are running — a simulated NoCappuccino frontend and backend. They're both on Docker's **default bridge network**. The frontend tries to reach the backend at `http://learn-ch04-backend:3000`, but gets:

```
Error: getaddrinfo ENOTFOUND learn-ch04-backend
    at GetAddrInfoReqWrap.onlookupall [as oncomplete] (node:dns:118:26) {
  errno: -3008,
  code: 'ENOTFOUND',
  syscall: 'getaddrinfo',
  hostname: 'learn-ch04-backend'
}
```

---

## Setup

Run these commands to create the broken environment:

```bash
# Pull the images first
docker pull nginx:alpine
docker pull alpine

# Start the "backend" on the default bridge (no --network flag)
docker run -d \
  --name learn-ch04-backend \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  nginx:alpine

# Start the "frontend" on the default bridge (no --network flag)
docker run -d \
  --name learn-ch04-frontend \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  alpine sleep 3600
```

**Verify the broken state:**

```bash
# This should fail with a DNS error:
docker exec learn-ch04-frontend ping -c 1 learn-ch04-backend
# ping: bad address 'learn-ch04-backend'
```

---

## Your Goal

Make `learn-ch04-frontend` able to reach `learn-ch04-backend` by name.

**Success condition:**

```bash
docker exec learn-ch04-frontend ping -c 1 learn-ch04-backend
# PING learn-ch04-backend (172.18.0.3): 56 data bytes
# 64 bytes from 172.18.0.3: seq=0 ttl=64 time=0.xxx ms
```

The ping must succeed using the container **name** — not an IP address.

---

## Constraints

- Do not stop or remove the containers if you can help it — Sarah needs the backend to stay up
- All new Docker resources must use the `learn-ch04-` prefix
- All new Docker resources must have labels: `--label app=learn-docker-k8s --label chapter=ch04`

---

## Hints

Only read these if you're stuck.

<details>
<summary>Hint 1 — General direction</summary>

The default bridge network doesn't support DNS resolution by container name. Think about what type of network does support it, and how you could move the containers onto one.

</details>

<details>
<summary>Hint 2 — Specific area</summary>

You don't have to restart the containers. There's a `docker network` subcommand that lets you attach a running container to a network after it was started.

Run `docker network --help` and look for something that sounds like "connect".

</details>

<details>
<summary>Hint 3 — Near answer</summary>

The flow is:
1. Create a new user-defined bridge network with `docker network create`
2. Connect both running containers to that network with `docker network connect NETWORK CONTAINER`
3. Test with `docker exec learn-ch04-frontend ping -c 1 learn-ch04-backend`

The network name must start with `learn-ch04-`.

</details>

---

## Verify

Once you think you've solved it, run the chapter's verify script:

```bash
bash curriculum/ch04-networking/challenges/verify.sh
```

Or ask Sarah to run it for you.

---

## Post-Mission Debrief (reveal after solving)

<details>
<summary>Show debrief</summary>

**What you did:**
You created a user-defined bridge network and connected both containers to it. Docker's embedded DNS server (at `127.0.0.11`) automatically registered both container names on the new network, enabling resolution.

**Why it works:**
The default `bridge` network predates Docker's embedded DNS feature and doesn't support automatic name resolution. User-defined bridges do. When you ran `docker network connect`, Docker added a new virtual interface (`eth1`) inside each container, attached to your new network, and registered both names with the DNS server on that network.

**Real-world connection:**
In Docker Compose (Chapter 5), every service automatically gets placed on a user-defined network. That's why Compose "just works" for service discovery — it does this step for you behind the scenes.

**Interview angle:**
"Why can't containers on the default bridge find each other by name?" is a classic Docker interview question. The answer: the default bridge doesn't activate Docker's embedded DNS. Only user-defined networks do.

**Pro tip:**
A container can be on multiple networks simultaneously. The backend in this challenge is still on the default bridge (where it can't be discovered by name) AND on your new network (where it can). You could disconnect it from the default bridge entirely with `docker network disconnect bridge learn-ch04-backend` to enforce clean isolation.

</details>

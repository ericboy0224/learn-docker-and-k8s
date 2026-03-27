# Lesson 1: Network Drivers

> "Before we fix the demo, let me show you what's actually happening. Docker networking is one of those things that seems like magic until you understand it — and then you realize it's just Linux being Linux."
> — Sarah

---

## The Problem in Plain English

Right now, `learn-ch04-frontend` and `learn-ch04-backend` are both running. But they can't talk to each other by name. When the frontend tries to reach `http://backend:3000`, Docker has no idea what `backend` means.

Why? Because they're on the **default bridge network**, which doesn't support container name resolution.

To understand the fix, you need to understand Docker's network model first.

---

## What Is a Docker Network?

Every container gets a virtual network interface. Docker connects containers to networks using a concept borrowed directly from Linux: the **bridge**.

Think of a Docker network as a private virtual switch inside your machine. Containers plugged into the same switch can talk to each other. Containers on different switches cannot — unless you build a bridge between them.

---

## Network Fundamentals: Virtual Switches and veth Pairs

When Docker creates a container, it does two things at the Linux level:

1. Creates a **veth pair** — a virtual ethernet cable with two ends. One end goes inside the container (as `eth0`). The other end connects to a bridge on the host.
2. Attaches that host-side end to a **Linux bridge** (think: virtual switch).

You can see this yourself:

```bash
# On the host, list network interfaces
ip link show

# You'll see entries like:
# veth3a8f2c1@if7: <BROADCAST,MULTICAST,UP,LOWER_UP>
# These are the host-side ends of container virtual cables
```

Each container connected to the same bridge can exchange Ethernet frames — just like physical machines plugged into the same switch.

---

## The Six Network Drivers

Docker ships with several network drivers. Each solves a different problem.

### 1. `bridge` (default)

The default for standalone containers. Docker creates a bridge called `docker0` on the host.

```bash
# See it:
ip link show docker0
# or
docker network inspect bridge
```

**The catch:** The default `bridge` network does **not** support DNS by container name. Containers get IPs, but those IPs change when containers restart. You can ping by IP, but that's fragile.

```bash
# Demonstrate the default bridge limitation:
docker run -d --name learn-ch04-test-a \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

docker run -d --name learn-ch04-test-b \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

# This FAILS on the default bridge:
docker exec learn-ch04-test-a ping -c 1 learn-ch04-test-b
# ping: bad address 'learn-ch04-test-b'

# But this WORKS (if you know the IP):
BACKEND_IP=$(docker inspect learn-ch04-test-b --format '{{.NetworkSettings.IPAddress}}')
docker exec learn-ch04-test-a ping -c 1 "$BACKEND_IP"

# Clean up:
docker rm -f learn-ch04-test-a learn-ch04-test-b
```

### 2. User-defined `bridge` (the fix)

When you create your own bridge network, Docker enables its **embedded DNS server** for that network. Containers can find each other by name.

```bash
# Create a user-defined bridge:
docker network create \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-app-net

# Now containers on this network CAN ping each other by name:
docker run -d --name learn-ch04-test-a \
  --network learn-ch04-app-net \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

docker run -d --name learn-ch04-test-b \
  --network learn-ch04-app-net \
  --label app=learn-docker-k8s --label chapter=ch04 \
  alpine sleep 60

# This WORKS:
docker exec learn-ch04-test-a ping -c 1 learn-ch04-test-b
# PING learn-ch04-test-b (172.18.0.3): 56 data bytes
# 64 bytes from 172.18.0.3: seq=0 ttl=64 time=0.156 ms

# Clean up:
docker rm -f learn-ch04-test-a learn-ch04-test-b
docker network rm learn-ch04-app-net
```

**This is the key insight for today's demo fix.**

### 3. `host`

The container shares the host's network namespace directly — no isolation, no virtual interface. The container uses the host's IP and ports as if it were a regular process.

```bash
docker run --rm --network host alpine ip addr
# You'll see the host's actual network interfaces
```

**When to use it:** Performance-critical situations where you need to eliminate network overhead. Rare in production. Not available on Docker Desktop for Mac/Windows (the Linux VM adds a layer).

**Safety note:** Using `--network host` means any port the container opens is immediately accessible on the host. No port mapping needed — or possible.

### 4. `none`

Complete network isolation. The container gets a loopback interface only.

```bash
docker run --rm --network none alpine ip addr
# Only: lo (loopback)

docker run --rm --network none alpine ping -c 1 1.1.1.1
# ping: bad address '1.1.1.1'
```

**When to use it:** Security-sensitive workloads (secret processors, batch jobs) that genuinely don't need network access.

### 5. `macvlan`

Assigns the container a real MAC address, making it appear as a physical device on your local network. The container gets an IP from your router's DHCP pool.

**When to use it:** Legacy apps that need to be on the same L2 network as physical machines. Requires special host configuration. Uncommon in typical development.

### 6. `overlay`

Used by Docker Swarm and Kubernetes to connect containers across **multiple hosts**. Creates a virtual network that spans machines.

You won't use this until Chapter 6 (Kubernetes). Filed under: "now you know it exists."

---

## The Essential Commands

```bash
# List all networks
docker network ls

# Inspect a network (see connected containers, subnet, gateway)
docker network inspect bridge
docker network inspect learn-ch04-app-net

# Create a user-defined bridge
docker network create \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-app-net

# Create with custom subnet
docker network create \
  --subnet 192.168.100.0/24 \
  --label app=learn-docker-k8s --label chapter=ch04 \
  learn-ch04-app-net

# Connect a running container to a network
docker network connect learn-ch04-app-net learn-ch04-frontend

# Disconnect a container from a network
docker network disconnect learn-ch04-app-net learn-ch04-frontend

# Remove a network (only works if no containers are attached)
docker network rm learn-ch04-app-net

# Remove all unused networks
docker network prune --filter "label=app=learn-docker-k8s"
```

---

## Default Bridge vs. User-defined Bridge: Side-by-Side

| Feature | Default `bridge` | User-defined bridge |
|---------|-----------------|---------------------|
| Container name DNS | No | **Yes** |
| Automatic IP resolution | No | **Yes** |
| Created by | Docker daemon (always exists) | You, with `docker network create` |
| Isolation from other containers | Partial | Full (unless explicitly connected) |
| `docker network connect` at runtime | No | **Yes** |
| Recommended for production | No | **Yes** |

> "This table is the single most important thing to remember from this lesson. The default bridge exists as a convenience. For real work, always create your own."
> — Sarah

---

## Key Takeaway

The default bridge network gives containers connectivity but not discoverability. User-defined bridge networks add Docker's embedded DNS, so containers find each other by name — not brittle IPs.

That's the root cause of the "host not found" error at NoCappuccino. The fix is in the next lesson.

---

**Next:** `lessons/02-dns-and-discovery.md` — How Docker's DNS actually works

# Lesson 3: Port Mapping Deep Dive

> "You've been typing `-p 8080:80` since Chapter 1 without thinking about it. Today we open the hood. There's a whole iptables ruleset firing every time a packet comes in — and knowing it will save you the next time nothing is reachable for no apparent reason."
> — Sarah

---

## The Problem This Solves

Containers live in their own network namespace. From the host machine's perspective, a container's internal port `80` doesn't exist — it's hidden behind the virtual network stack.

Port mapping creates a **forwarding rule** at the host level: "any traffic arriving on host port 8080 should be forwarded to this container's port 80."

```
[Host: 0.0.0.0:8080] ──iptables NAT──> [Container eth0: 172.17.0.2:80]
```

---

## What `-p` Actually Does

When you run:

```bash
docker run -p 8080:80 nginx:alpine
```

Docker does the following:

1. **Binds a port** on the host at `0.0.0.0:8080` (all interfaces, by default)
2. **Writes iptables rules** to NAT (Network Address Translate) incoming traffic on port 8080 to the container's IP and port 80
3. Manages these rules automatically — when the container stops, rules are removed

You can see Docker's iptables rules yourself (on Linux or inside Docker Desktop's VM):

```bash
# List Docker's NAT rules:
iptables -t nat -L DOCKER --line-numbers -n
# Chain DOCKER (2 references)
# num  target     prot opt source               destination
# 1    RETURN     all  --  127.0.0.0/8          0.0.0.0/0
# 2    DNAT       tcp  --  0.0.0.0/0            0.0.0.0/0   tcp dpt:8080 to:172.17.0.2:80
```

On macOS, Docker Desktop runs a Linux VM. The iptables rules live inside that VM — you can't see them directly from your Mac terminal, but the forwarding behavior is identical.

---

## NAT Explained

NAT stands for Network Address Translation. It's a technique where a router (or in this case, the host kernel) rewrites packet headers as they pass through.

**Incoming packet (DNAT — Destination NAT):**
```
Before iptables:  src=your-laptop:54321  dst=host:8080
After iptables:   src=your-laptop:54321  dst=172.17.0.2:80
```

**Outgoing reply (SNAT — Source NAT / masquerade):**
```
Before iptables:  src=172.17.0.2:80  dst=your-laptop:54321
After iptables:   src=host:8080      dst=your-laptop:54321
```

The container never knows it's being NAT'd. It just sees a regular TCP connection.

---

## TCP/IP in 60 Seconds

Since port mapping touches TCP/IP directly, here's the minimum you need:

- **IP address:** identifies a machine (or container) on a network. Layer 3.
- **Port number:** identifies a specific service on that machine. Layer 4.
- **TCP:** a reliable, connection-oriented protocol. SYN → SYN-ACK → ACK to establish, then data flows.
- **`0.0.0.0`:** "all interfaces" — listen on every network interface
- **`127.0.0.1`:** loopback — only accessible from the same machine
- **`localhost`:** resolves to `127.0.0.1` (usually)

When your Node.js app calls `server.listen(3000)`, it binds to `0.0.0.0:3000` by default on most frameworks — but some explicitly bind to `127.0.0.1:3000`. That distinction matters enormously in containers.

---

## Binding Address: `0.0.0.0` vs `127.0.0.1` vs Specific IP

The `-p` flag has a third optional component: the host bind address.

### Format

```
-p [host_ip:]host_port:container_port
```

### Examples

```bash
# Bind on ALL host interfaces (default) — reachable from anywhere:
docker run -p 8080:80 nginx:alpine
# Same as:
docker run -p 0.0.0.0:8080:80 nginx:alpine

# Bind ONLY on loopback — only reachable from the host itself:
docker run -p 127.0.0.1:8080:80 nginx:alpine

# Bind on a specific host IP:
docker run -p 192.168.1.100:8080:80 nginx:alpine
```

### Why does this matter?

If you bind to `0.0.0.0:8080`, your container is accessible from:
- Your local machine
- Other machines on your LAN
- Potentially from the internet (if there's no firewall)

If you bind to `127.0.0.1:8080`, your container is accessible **only** from localhost. A common security practice for databases and internal services that shouldn't be exposed.

```bash
# Demonstrate the difference:

# Only reachable from host:
docker run -d --name learn-ch04-localhost-only \
  --label app=learn-docker-k8s --label chapter=ch04 \
  -p 127.0.0.1:8081:80 \
  nginx:alpine

curl http://localhost:8081   # Works
curl http://0.0.0.0:8081     # Works (same machine)
# But from another machine on your network: would fail

# Reachable from everywhere:
docker run -d --name learn-ch04-public \
  --label app=learn-docker-k8s --label chapter=ch04 \
  -p 0.0.0.0:8082:80 \
  nginx:alpine

curl http://localhost:8082    # Works
# Also works from other machines at http://YOUR_HOST_IP:8082

# Clean up:
docker rm -f learn-ch04-localhost-only learn-ch04-public
```

---

## EXPOSE: The Misunderstood Keyword

You'll see `EXPOSE 80` in Dockerfiles. Here's what it does — and doesn't do.

```dockerfile
FROM nginx:alpine
EXPOSE 80
```

**What `EXPOSE` does:**
- Documents that the container intends to listen on port 80
- Makes the port available to `docker run -P` (auto-assign a host port)
- Visible in `docker inspect` and on Docker Hub

**What `EXPOSE` does NOT do:**
- It does NOT publish the port
- It does NOT make the service accessible from outside the container
- It does NOT create any iptables rules

Think of `EXPOSE` as a comment in your Dockerfile that happens to be machine-readable.

```bash
# Build an image with EXPOSE 80:
# (nginx:alpine already has EXPOSE 80 in its Dockerfile)

# Without -p, EXPOSE does nothing for external access:
docker run -d --name learn-ch04-exposed-only \
  --label app=learn-docker-k8s --label chapter=ch04 \
  nginx:alpine

curl http://localhost:80   # Connection refused — EXPOSE alone is not enough

# With -P (capital P), Docker auto-assigns a random host port:
docker run -d --name learn-ch04-auto-port \
  --label app=learn-docker-k8s --label chapter=ch04 \
  -P nginx:alpine

docker port learn-ch04-auto-port
# 80/tcp -> 0.0.0.0:32768

curl http://localhost:32768   # Works!

# Clean up:
docker rm -f learn-ch04-exposed-only learn-ch04-auto-port
```

**Interview trap:** "Does EXPOSE publish a port?" Answer: No. It only documents intent and enables `-P`.

---

## The Critical Trap: App Binding Inside the Container

This is the root cause of Challenge 2 — pay attention.

Port mapping only works if the application inside the container is listening on the right interface.

Here's the trap: if your Node.js app does this —

```js
// Bad for containers:
const server = app.listen(3000, '127.0.0.1', () => {
  console.log('Listening on 127.0.0.1:3000');
});
```

— it binds to the container's loopback interface. Docker's port mapping sends traffic to `container_ip:3000` (the container's `eth0`), but the app isn't listening there. The connection is refused.

```
[Host port 3000] -iptables-> [Container eth0:3000] X [Container lo:3000] <- app
```

The fix is always to bind to `0.0.0.0` inside the container:

```js
// Correct for containers:
const server = app.listen(3000, '0.0.0.0', () => {
  console.log('Listening on 0.0.0.0:3000');
});
```

Or just omit the address (most frameworks default to `0.0.0.0`):

```js
const server = app.listen(3000);
```

You'll encounter this exact problem in Challenge 2.

---

## Inspecting Port Mappings

```bash
# See all mapped ports for a container:
docker port learn-ch04-nginx

# See port info inside docker inspect:
docker inspect learn-ch04-nginx \
  --format '{{json .NetworkSettings.Ports}}' | python3 -m json.tool

# See all containers with their ports:
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

---

## Quick Reference: `-p` Syntax

| Flag | Effect |
|------|--------|
| `-p 8080:80` | Host 8080 → Container 80, all interfaces |
| `-p 127.0.0.1:8080:80` | Host loopback 8080 → Container 80 only |
| `-p 80` | Random host port → Container 80 |
| `-P` | Auto-map all `EXPOSE`d ports to random host ports |
| No `-p` flag | Container port accessible only from other containers |

---

## Key Takeaways

1. `-p host_port:container_port` writes iptables DNAT rules — traffic is NAT'd from host to container
2. `EXPOSE` is documentation, not publication — it does not open any port
3. The bind address on the host (`0.0.0.0` vs `127.0.0.1`) controls who can reach the mapped port
4. The bind address **inside the container** must be `0.0.0.0` — otherwise port mapping silently fails
5. Use `127.0.0.1:host_port:container_port` for services that should only be reachable locally (databases, admin panels)

---

**Up next:** Challenge time. Let's fix NoCappuccino.

# Challenge 2: Fix the Binding

> "Demo went great! The investors loved it. But Marcus just signed a deal with a new partner — they want to integrate with our API. I spun up an instance to demo the integration, mapped the port, and... nothing. I can't curl it from the host. The container is running, port is mapped, logs look fine. I'm losing my mind."
> — Sarah

---

## The Situation

A Node.js application is running inside a container. The port is mapped with `-p 3000:3000`. But when you try to reach it from the host, you get:

```
curl: (7) Failed to connect to localhost port 3000 after 0 ms: Connection refused
```

The container is definitely running. The port mapping looks correct. Something else is wrong.

---

## Setup

Build and run the broken application:

```bash
# Create the app directory
mkdir -p /tmp/learn-ch04-broken-app

# Create the broken server (binds to 127.0.0.1 inside the container)
cat > /tmp/learn-ch04-broken-app/server.js << 'EOF'
const http = require('http');

const HOST = '127.0.0.1';  // <-- this is the problem
const PORT = 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'ok',
    message: 'NoCappuccino API v1.0',
    timestamp: new Date().toISOString()
  }));
});

server.listen(PORT, HOST, () => {
  console.log(`Server running at http://${HOST}:${PORT}/`);
});
EOF

# Create the Dockerfile
cat > /tmp/learn-ch04-broken-app/Dockerfile << 'EOF'
FROM node:18-alpine
WORKDIR /app
COPY server.js .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Build the image
docker build \
  -t learn-ch04-api:broken \
  /tmp/learn-ch04-broken-app

# Run the broken container
docker run -d \
  --name learn-ch04-api \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  -p 3000:3000 \
  learn-ch04-api:broken
```

**Verify the broken state:**

```bash
# The container is running:
docker ps --filter name=learn-ch04-api
# CONTAINER ID   IMAGE                  COMMAND           ...   STATUS    PORTS
# abc123...      learn-ch04-api:broken  "node server.js"  ...   Up 5s     0.0.0.0:3000->3000/tcp

# Logs look fine:
docker logs learn-ch04-api
# Server running at http://127.0.0.1:3000/

# But this fails:
curl http://localhost:3000
# curl: (7) Failed to connect to localhost port 3000 after 0 ms: Connection refused
```

---

## Your Goal

Fix the application so that `curl http://localhost:3000` from the **host machine** returns:

```json
{"status":"ok","message":"NoCappuccino API v1.0","timestamp":"..."}
```

---

## Constraints

- The fix must be in the application code or Dockerfile — not a workaround at the Docker level
- Build the fixed image as `learn-ch04-api:fixed`
- Run the fixed container as `learn-ch04-api-fixed`
- Use labels: `--label app=learn-docker-k8s --label chapter=ch04`
- Keep the original `learn-ch04-api` container running (for comparison)

---

## Hints

Only read these if you're stuck.

<details>
<summary>Hint 1 — General direction</summary>

The container is running and the port mapping is correct. The problem is inside the container. Look at what address the application is listening on — and think about where Docker's port forwarding actually sends traffic.

</details>

<details>
<summary>Hint 2 — Specific area</summary>

Inside a container, `127.0.0.1` is the container's own loopback interface. Docker's port mapping sends incoming traffic to the container's `eth0` interface — which has a different IP (something like `172.17.0.x`). If the app only listens on `127.0.0.1`, it will never receive traffic arriving on `eth0`.

Look at the `HOST` variable in `server.js`.

</details>

<details>
<summary>Hint 3 — Near answer</summary>

Change the `HOST` constant in `server.js` from `'127.0.0.1'` to `'0.0.0.0'`. This tells Node.js to listen on all network interfaces inside the container — including the `eth0` interface that Docker's port mapping forwards traffic to.

Then rebuild the image and run the new container:
```bash
# Edit /tmp/learn-ch04-broken-app/server.js
# Change: const HOST = '127.0.0.1';
# To:     const HOST = '0.0.0.0';

docker build -t learn-ch04-api:fixed /tmp/learn-ch04-broken-app

docker run -d \
  --name learn-ch04-api-fixed \
  --label app=learn-docker-k8s \
  --label chapter=ch04 \
  -p 3001:3000 \
  learn-ch04-api:fixed
```

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
You changed the bind address in the Node.js application from `127.0.0.1` to `0.0.0.0`, rebuilt the image, and reran the container.

**Why it works:**
Inside a container, `127.0.0.1` is the loopback interface — traffic on it never leaves the container's network namespace. Docker's port mapping (iptables DNAT) forwards incoming host traffic to the container's `eth0` interface, which has a different IP (e.g., `172.17.0.2`). If the app binds only to `127.0.0.1`, it never sees this forwarded traffic. Binding to `0.0.0.0` means "listen on all interfaces" — including `eth0`.

**Real-world connection:**
This is one of the most common Docker bugs in the wild. It often surfaces when migrating existing applications into containers. The app worked fine on bare metal (where `localhost` is the machine itself), but breaks in a container (where `localhost` is isolated). The standard fix is to configure all containerized services to bind to `0.0.0.0`.

**Interview angle:**
"I have a containerized app, port is mapped with `-p`, the container is running, but I get connection refused. What would you check?" — check whether the app inside is binding to `127.0.0.1` vs `0.0.0.0`. This is a real answer that impresses interviewers.

**Pro tip:**
You can verify what address a process is listening on inside the container without changing the app:
```bash
docker exec learn-ch04-api netstat -tlnp
# or
docker exec learn-ch04-api ss -tlnp
```
Look for the local address column: `127.0.0.1:3000` means loopback only; `0.0.0.0:3000` means all interfaces.

</details>

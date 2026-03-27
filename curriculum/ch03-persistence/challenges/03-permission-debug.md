# Challenge 03: Permission Debug

> **Difficulty:** Intermediate
> **Estimated time:** 25–30 minutes

---

## Situation

The NoCappuccino ops team has a security policy: no production containers run as root. Dave got the memo and added a `USER` directive to the preferences API Dockerfile.

Then the app stopped writing logs.

The container starts up, everything looks fine — but when the app tries to write to the volume-mounted `/app/logs` directory, it fails with `Permission denied`. The logs directory was created by root (Docker defaults), and the app is running as a non-root user.

This is one of the most common frustrations when combining volumes with proper container security. Your job is to diagnose it and fix it.

---

## The Broken App

Create this `Dockerfile` at a path of your choice on your host — for example, `~/cloudbrew-logger/Dockerfile`:

```dockerfile
FROM node:20-alpine

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy application
COPY index.js .

# Switch to non-root user
USER appuser

# Start the app
CMD ["node", "index.js"]
```

And the `index.js` it uses:

```javascript
// index.js — NoCappuccino Logger (intentionally broken)
const fs = require('fs');
const path = require('path');
const http = require('http');

const LOG_DIR = '/app/logs';
const LOG_FILE = path.join(LOG_DIR, 'requests.log');
const PORT = 3000;

// Ensure log directory exists and is writable
try {
  fs.mkdirSync(LOG_DIR, { recursive: true });
  fs.writeFileSync(LOG_FILE, `Server started at ${new Date().toISOString()}\n`, { flag: 'a' });
  console.log('Log file ready:', LOG_FILE);
} catch (err) {
  console.error('FATAL: Cannot write to log directory:', err.message);
  process.exit(1);
}

const server = http.createServer((req, res) => {
  const entry = `${new Date().toISOString()} ${req.method} ${req.url}\n`;
  fs.appendFileSync(LOG_FILE, entry);
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Request logged.\n');
});

server.listen(PORT, () => {
  console.log(`NoCappuccino Logger listening on port ${PORT}`);
});
```

---

## Your Mission

1. Build the image as **`learn-ch03-perm-app:broken`** from the Dockerfile above.

2. Create a named volume **`learn-ch03-app-logs`** with labels `app=learn-docker-k8s` and `chapter=ch03`.

3. Run a container named **`learn-ch03-logger`** with labels `app=learn-docker-k8s` and `chapter=ch03`, mounting the volume at `/app/logs` and mapping port `3000`.

4. Observe that the container exits immediately with a permission error.

5. **Diagnose the exact cause** of the permission error — who owns `/app/logs`, and what UID is `appuser` running as?

6. **Fix it** without removing the `USER appuser` directive — the security requirement stands.

7. Build the fixed image as **`learn-ch03-perm-app:fixed`**, run a new container, verify the app starts successfully, and confirm that `curl http://localhost:3000` logs a request to the volume.

---

## Requirements Summary

- Fixed image tag: `learn-ch03-perm-app:fixed`
- Container name: `learn-ch03-logger`
- Labels: `app=learn-docker-k8s`, `chapter=ch03`
- Volume: `learn-ch03-app-logs` mounted at `/app/logs`
- Port mapping: host `3000` → container `3000`
- `USER appuser` must remain in the Dockerfile
- The app must start without errors and log to the volume

---

## Success Condition

Running `verify.sh` outputs:
```
PASS: Image 'learn-ch03-perm-app:fixed' exists
PASS: Container 'learn-ch03-logger' is running
PASS: Port 3000 is accessible
PASS: Volume 'learn-ch03-app-logs' exists
PASS: Log file exists inside the volume

All checks passed! Challenge complete!
```

---

## Hints

<details>
<summary>Hint 1 — Understanding the failure</summary>

When Docker mounts a named volume into a container, the volume directory is owned by root (UID 0) by default. Inside the container, `appuser` is a non-root user with a different UID — likely `1000` or similar. Linux filesystem permissions apply: if the directory is owned by root and the process running as `appuser` tries to write to it, it gets `Permission denied`.

Run `docker logs learn-ch03-logger` to see the exact error. Then use `docker run --rm -v learn-ch03-app-logs:/inspect alpine ls -la /inspect` to check who owns the volume's root directory.

What UID does `appuser` have? You can check with: `docker run --rm learn-ch03-perm-app:broken id appuser`

</details>

<details>
<summary>Hint 2 — The approaches to fixing it</summary>

There are several ways to fix a permission mismatch. Think about *where* in the process the fix should happen:

**Option A:** Make the directory writable *before* the `USER` switch in the Dockerfile. If you create `/app/logs` and set the right ownership while you are still running as root in the Dockerfile, the directory will have the correct permissions when `appuser` tries to use it.

**Option B:** Change the ownership of the mounted volume from inside an init step. This is a more complex pattern (often seen with entrypoint scripts) and is less clean for this scenario.

**Option C:** Run the container with `--user root` to bypass the `USER` directive. This defeats the security purpose — do not do this.

Option A is the right approach here. Which Dockerfile instructions let you set up directories and change their ownership?

</details>

<details>
<summary>Hint 3 — The Dockerfile fix</summary>

The key is to create the log directory and `chown` it to `appuser` *before* the `USER appuser` line. While the Dockerfile is still running as root, you have full permission to set up the filesystem:

```dockerfile
# Create the log directory and give appuser ownership
RUN mkdir -p /app/logs && chown -R appuser:appgroup /app/logs
```

This line goes *after* the `adduser` command (so `appuser` exists) and *before* the `USER appuser` line (so you still have root privileges to run `chown`).

After adding this, rebuild as `learn-ch03-perm-app:fixed` and rerun the container.

</details>

---

## Post-Challenge Reflection

This challenge demonstrates a real security/usability tension in container design. Consider:

- Why do Docker volumes initialize as root-owned? (Think about what the Docker daemon runs as.)
- What does the `USER` directive actually change? Does it affect the `RUN` instructions before it?
- In Kubernetes, there is a `securityContext.runAsUser` and `fsGroup` field in the pod spec that handles exactly this problem at the orchestration level. How might that be cleaner than a Dockerfile fix?
- What happens if you mount a bind mount instead of a named volume? The host directory ownership determines the permissions — a different set of problems.

---

## Resources

- `docker logs learn-ch03-logger`
- `docker inspect learn-ch03-logger`
- `docker run --rm ... alpine ls -la /path` (to inspect volume permissions)
- [Dockerfile reference: USER instruction](https://docs.docker.com/reference/dockerfile/#user)
- [Lesson 02: Volumes and Mounts](../lessons/02-volumes-and-mounts.md) — the bind mounts and named volumes sections

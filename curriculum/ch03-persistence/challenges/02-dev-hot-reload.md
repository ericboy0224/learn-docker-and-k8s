# Challenge 02: Dev Hot Reload

> **Difficulty:** Beginner
> **Estimated time:** 20–25 minutes

---

## Situation

A new developer, Priya, just joined NoCappuccino. She is setting up her local environment to work on the preferences API. Her current workflow: edit a file, rebuild the Docker image, stop the container, start the new container, test. Every single change.

It takes about 90 seconds per iteration. She made her feelings known in Slack with a series of escalating coffee emoji.

You are going to show her a better way using bind mounts. Edit a file on your host, the container reflects the change instantly — no rebuild required.

---

## The App

Here is the Node.js app Priya is working on. Create this file at a path of your choice on your host — for example, `~/cloudbrew-app/index.js`:

```javascript
// index.js — NoCappuccino Preferences API (dev version)
const http = require('http');

const PORT = 3000;
const GREETING = 'Welcome to NoCappuccino! Your preferences are safe.';

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end(GREETING + '\n');
});

server.listen(PORT, () => {
  console.log(`NoCappuccino API listening on port ${PORT}`);
});
```

And a `package.json` in the same directory:

```json
{
  "name": "cloudbrew-api",
  "version": "1.0.0",
  "description": "NoCappuccino customer preferences API",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "node --watch index.js"
  }
}
```

---

## Your Mission

1. Run the Node.js app inside a container using a **bind mount** so the container reads the source files directly from your host filesystem.

2. The container must run the app with **`node --watch`** (or `nodemon`) so it automatically restarts when `index.js` changes.

3. The container must be named **`learn-ch03-node-app`** with labels `app=learn-docker-k8s` and `chapter=ch03`, and port `3000` must be mapped to the host.

4. Verify the initial app is working:
   ```bash
   curl http://localhost:3000
   # → Welcome to NoCappuccino! Your preferences are safe.
   ```

5. **Edit `index.js` on your host** — change the `GREETING` string to something different. Save the file.

6. Verify that `curl http://localhost:3000` now returns the updated response **without restarting or rebuilding the container**.

---

## Requirements Summary

- Container name: `learn-ch03-node-app`
- Labels: `app=learn-docker-k8s`, `chapter=ch03`
- Image: `node:20-alpine`
- Port mapping: host `3000` → container `3000`
- Bind mount: your local app directory → `/app` inside the container
- Working directory inside container: `/app`
- Start command: `node --watch index.js`

---

## Success Condition

Running `verify.sh` outputs:
```
PASS: Container 'learn-ch03-node-app' is running
PASS: Port 3000 is accessible
PASS: Response changed after file edit (hot reload is working)

All checks passed! Challenge complete!
```

The verify script will edit `index.js` and check that `curl` returns the updated content — so make sure the bind mount is set up correctly before running it.

---

## Hints

<details>
<summary>Hint 1 — Mounting your source code</summary>

The bind mount flag takes the form `-v /absolute/host/path:/container/path`. You need to give Docker the full absolute path to the directory containing `index.js` on your host. If you are in that directory, `$(pwd)` gives you the absolute path in a shell command.

The container also needs to know which directory to run commands from — look at the `--workdir` or `-w` flag for `docker run`.

</details>

<details>
<summary>Hint 2 — Getting the start command right</summary>

The `docker run` command takes the image name and then the command to run. The `node:20-alpine` image will execute whatever command you pass after the image name. You want to run `node --watch index.js` inside `/app`.

The `--watch` flag (available in Node.js 18+) restarts the process when it detects file changes. Because your file is coming from the host via a bind mount, changes you make on the host are immediately visible inside the container, and `--watch` picks them up.

If you want to see the restart happening, use `docker logs -f learn-ch03-node-app` in a separate terminal while you edit the file.

</details>

<details>
<summary>Hint 3 — Putting it all together</summary>

Your `docker run` command needs these pieces in order:
1. `-d` (detached mode)
2. `--name learn-ch03-node-app`
3. `--label app=learn-docker-k8s --label chapter=ch03`
4. `-p 3000:3000`
5. `-v /your/absolute/path/to/cloudbrew-app:/app`
6. `-w /app`
7. `node:20-alpine`
8. `node --watch index.js`

Once the container is running, edit `GREETING` in your host's `index.js`, save, and watch the container logs to see the restart. Then curl again.

</details>

---

## Going Further

Once the challenge passes, try these experiments:

- Add a second route to the app (e.g., `/health` returns `{"status":"ok"}`). Does it hot-reload correctly?
- What happens if you delete `index.js` on the host while the container is running?
- Try using `--mount type=bind,source=...,target=/app` instead of `-v`. Is it clearer?
- What is the difference between mounting the directory (`/app`) versus mounting just the file (`/app/index.js`)?

---

## Resources

- `docker run --help` (look for `--volume`, `--workdir`, `--publish`)
- `node --watch` documentation: `node --help | grep watch`
- [Lesson 02: Volumes and Mounts](../lessons/02-volumes-and-mounts.md) — the bind mounts section

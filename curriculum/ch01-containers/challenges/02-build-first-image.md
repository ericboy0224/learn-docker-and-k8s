# Challenge 02: Build Your First Image

*Sarah speaking:* Running existing images is great, but the real skill is building your own. This is what Dave needs — not just "I can run nginx," but "I can take our application code and bake it into a container image."

Let's do that now with a tiny Node.js app.

---

## The Situation

Dave's Aroma-Discovery API is complex, but the concept is the same for any Node app. We're going to build a simplified version — a "Hello NoCappuccino" server — and Dockerize it from scratch. You'll create the app files, write the Dockerfile, build the image, and run it.

---

## The Application Code

Create a directory for this challenge and add these two files exactly as shown.

### `package.json`

```json
{
  "name": "cloudbrew-api",
  "version": "1.0.0",
  "description": "NoCappuccino Hello API",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

### `index.js`

```javascript
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello from NoCappuccino!');
});

app.listen(PORT, () => {
  console.log(`NoCappuccino API running on port ${PORT}`);
});
```

That's it — a five-line Express server that listens on port 3000 and responds with "Hello from NoCappuccino!" at the root path.

---

## Requirements

You must:

1. Write a `Dockerfile` in the same directory as the app files that:
   - Uses an official Node.js base image
   - Installs the npm dependencies
   - Copies the application code into the image
   - Exposes port 3000
   - Sets the default command to start the server

2. Build the image with the tag `learn-ch01-app:v1`

3. Run a container from that image that:
   - Is named `learn-ch01-app`
   - Is accessible at `http://localhost:3000` on your host
   - Runs in detached mode
   - Has both labels applied:
     - `--label app=learn-docker-k8s`
     - `--label chapter=ch01`

---

## Success Criteria

Run the verification script:

```bash
bash curriculum/ch01-containers/challenges/verify.sh
```

Or manually verify:

```bash
curl http://localhost:3000
```

Expected output:
```
Hello from NoCappuccino!
```

---

## Hints

<details>
<summary>Hint 1 — Where to start with the Dockerfile</summary>

A Dockerfile is a plain text file named `Dockerfile` (no extension). Every Dockerfile starts with a `FROM` instruction that names the base image.

For a Node.js app, look at Docker Hub for official Node images. The `node:18-alpine` image is a good choice — it has Node 18 on the minimal Alpine base. Think about what instructions you need to: set a working directory, copy files, run `npm install`, and specify the start command.

</details>

<details>
<summary>Hint 2 — Dockerfile instructions to use</summary>

You'll need these instructions, roughly in this order:

- `FROM` — which base image to start from
- `WORKDIR` — set the working directory inside the container (e.g., `/app`)
- `COPY` — copy files from your host into the image
- `RUN` — execute a command during the build (e.g., `npm install`)
- `EXPOSE` — document which port the app listens on
- `CMD` — the default command to run when a container starts

Copy `package.json` and `package-lock.json` (if it exists) *before* copying your code. This way Docker can cache the `npm install` layer and skip it on rebuilds when only your code changes.

</details>

<details>
<summary>Hint 3 — Build and run commands</summary>

To build an image from a Dockerfile in the current directory:

```
docker build -t learn-ch01-app:v1 .
```

The `-t` flag sets the image name and tag. The `.` means "look for the Dockerfile in the current directory."

Once the image is built, use `docker run` with the appropriate flags (see Challenge 01 as a reference for the pattern). Map the container's port 3000 to your host's port 3000.

</details>

---

## Why This Matters

What you just did is the fundamental unit of modern deployment. Once `learn-ch01-app:v1` exists as an image, it can be pulled and run anywhere with Docker — the same way, every time. Dave's version mismatch problem? Gone. The staging server doesn't need Node installed at all. It just needs Docker.

---

## Cleanup

```bash
docker stop learn-ch01-app && docker rm learn-ch01-app
```

The image `learn-ch01-app:v1` stays until you remove it with `docker rmi learn-ch01-app:v1` — or run the global cleanup.

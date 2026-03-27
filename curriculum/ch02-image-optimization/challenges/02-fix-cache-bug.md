# Challenge 2: Fix the Cache Bug

## The Situation

Good news: you've shrunk the Bean-Tracker image significantly. Bad news: the frontend team is complaining that their builds still take forever.

You look at their Dockerfile. Two problems jump out immediately.

"Oh," you say, quietly.

Junior dev Priya looks over your shoulder. "Is it bad?"

"It's... instructive."

---

## Your Mission

The frontend service has a Dockerfile with two distinct caching bugs. Every time a developer changes *any* file — even a one-character fix in `app.js` — the build reinstalls all dependencies from scratch. On a project with 300+ npm packages, that's a 3-minute wait every single time.

Your job: fix both bugs so that rebuilding after a code-only change uses the cache for the dependency install step.

**Success criteria:** After fixing the Dockerfile and building once (to warm the cache), changing only `src/app.js` and rebuilding should show `CACHED` on the `npm install` step.

---

## The Files

Create this directory structure to work in:

```
challenges/cache-bug/
  Dockerfile          <- You will fix this file
  package.json
  package-lock.json
  src/
    app.js
```

**`challenges/cache-bug/Dockerfile`** — The broken Dockerfile (create it with the content below)

**`challenges/cache-bug/package.json`** — Create this file:

```json
{
  "name": "bean-tracker-frontend",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

**`challenges/cache-bug/package-lock.json`** — Create this file:

```json
{
  "name": "bean-tracker-frontend",
  "version": "1.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {}
}
```

**`challenges/cache-bug/src/app.js`** — Create this file:

```javascript
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('NoCappuccino Frontend - Bean selection interface v1.0\n');
});

app.listen(port, () => {
  console.log(`Frontend running on port ${port}`);
});
```

---

## The Broken Dockerfile

Create `challenges/cache-bug/Dockerfile` with exactly this content:

```dockerfile
FROM node:20

WORKDIR /app

# Bug is in here somewhere...
COPY . .

RUN apt-get update
RUN apt-get install -y curl

RUN npm install

EXPOSE 3000

CMD ["node", "src/app.js"]
```

---

## Your Task

1. Create the files listed above
2. Fix the Dockerfile — there are **two separate bugs**
3. Build the fixed version:

```bash
docker build \
  -t learn-ch02-cache-fixed:latest \
  challenges/cache-bug/
```

4. Now make a small change to `challenges/cache-bug/src/app.js` (add a comment, change the response message, anything)
5. Build again and verify that `npm install` shows `CACHED`:

```bash
docker build \
  --progress=plain \
  -t learn-ch02-cache-fixed:latest \
  challenges/cache-bug/
```

Look for this in the output:
```
#X [X/X] RUN npm install
#X CACHED
```

---

## Requirements

- The image must be tagged `learn-ch02-cache-fixed:latest`
- After building once to warm the cache, a code-only change must NOT trigger a full `npm install`
- The `apt-get update` and `apt-get install` commands must be chained in a single `RUN` instruction
- The image must contain no `apt-get` package index at runtime (clean up `/var/lib/apt/lists/`)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

There are two separate problems in this Dockerfile. One is about the order in which files are copied versus when dependencies are installed. The other is about a well-known apt-get anti-pattern that can cause builds to fail or use stale packages months down the line.

Re-read Lesson 2, specifically the sections "The Dependency-Before-Source Pattern" and "The Stale apt-get Bug".

</details>

<details>
<summary>Hint 2 — Specific areas</summary>

**Bug 1 (ordering):** The line `COPY . .` copies all your source code before `npm install`. This means any change to any file — including `src/app.js` — invalidates the cache before `npm install` runs. Think about what files `npm install` actually needs to do its job. Does it need `src/app.js`? Or just `package.json` and `package-lock.json`?

**Bug 2 (apt-get):** `apt-get update` and `apt-get install` are on separate `RUN` lines. If someone adds a package to the install list later, Docker will reuse the old `apt-get update` layer (with a stale package index) and run only the install. This can cause "Unable to locate package" errors. Always chain them.

</details>

<details>
<summary>Hint 3 — Near-answer guidance</summary>

Fix 1: Replace the single `COPY . .` with two separate copy steps:
```dockerfile
COPY package*.json ./     # Copy only the dependency manifest
RUN npm install           # Install (now cached separately from source)
COPY . .                  # Copy source (changes don't bust npm install cache)
```

Fix 2: Merge the two `apt-get` lines into one and clean up afterward:
```dockerfile
RUN apt-get update && apt-get install -y \
    --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

Make sure `apt-get` comes *before* `npm install` if curl is needed during the install.

</details>

---

## Verification

Run the chapter verify script to check this challenge:

```bash
bash curriculum/ch02-image-optimization/challenges/verify.sh
```

Or test manually:

```bash
# 1. Build once to warm the cache
docker build -t learn-ch02-cache-fixed:latest challenges/cache-bug/

# 2. Touch the source file
echo "// cache test" >> challenges/cache-bug/src/app.js

# 3. Rebuild with plain output — look for CACHED on npm install
docker build --progress=plain -t learn-ch02-cache-fixed:latest challenges/cache-bug/ 2>&1 | grep -A1 "npm install"
```

---

## Post-Challenge Debrief

Once you pass, think about these questions:

1. **What you did:** You fixed the layer ordering so that npm's dependency manifest is copied and installed before the application source, isolating the expensive install step from frequent code changes. You also fixed the apt-get anti-pattern to avoid the stale package index problem.

2. **Why it works:** Docker's cache is keyed on the *content* of what each instruction operates on. By copying only `package.json` first, the `RUN npm install` layer's cache key only changes when dependencies actually change — not when application code changes.

3. **Real-world connection:** In a team of 10 developers each building the image 5 times a day, this change saves roughly 3 minutes × 50 builds = 2.5 hours of collective waiting per day. For a CI/CD pipeline running 50 builds per day, it's the difference between a CI job taking 4 minutes vs. 30 seconds.

4. **Interview angle:** "How does Docker layer caching work?" and "How do you optimize a Dockerfile for fast incremental builds?" are common DevOps interview questions.

5. **Pro tip:** On Alpine-based images (`node:20-alpine`), the package manager is `apk`, not `apt-get`. If you ever switch to Alpine, replace `apt-get` with `apk add --no-cache curl`. The Debian-based `node:20` image used here supports `apt-get` but is larger — a common trade-off when you need system packages.

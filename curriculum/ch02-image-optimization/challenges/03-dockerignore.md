# Challenge 3: Tame the Build Context

## The Situation

New developer Alex just pushed their first Docker build to CI. The build log starts with:

```
=> transferring context: 487.32MB
```

487 megabytes. Before a single instruction runs. Your Slack lights up.

"Why is the CI build timing out?" — Alex

"Why is the artifact storage 40% full?" — Platform team

"Why did my $200 build minutes quota disappear in one afternoon?" — Marcus, clearly

You look at Alex's project directory. There it is: a `node_modules` folder with 180MB of packages, a `.git` directory with 200MB of history, and a `test-data/` folder with 100MB of sample images someone committed by accident three years ago.

"Alex," you say gently, "we need to talk about build context."

---

## Background: What Is the Build Context?

When you run `docker build .`, Docker sends the entire current directory to the Docker daemon as the "build context." The daemon needs this because `COPY` instructions in the Dockerfile reference files relative to this context.

The problem: Docker sends *everything* — including things you never `COPY` into the image. It's like emailing your entire hard drive when someone asks for a specific document.

The `.dockerignore` file tells Docker which files and directories to exclude from the build context. It uses the same syntax as `.gitignore`.

---

## Your Mission

You have a project directory where the build context is over 400MB because `node_modules` and `.git` are being sent to the daemon. Your job is to create a `.dockerignore` file that reduces the build context to under **1MB**.

**Success criteria:** Running `docker build` shows `transferring context` under 1MB.

---

## Setup

First, let's create the test project. Run these commands to set up the directory:

```bash
# Create the project directory
mkdir -p challenges/big-context/src

# Create a simple Node.js app
cat > challenges/big-context/src/index.js << 'EOF'
const http = require('http');
const server = http.createServer((req, res) => {
  res.writeHead(200);
  res.end('NoCappuccino - Roasting microservice v2.0\n');
});
server.listen(3000, () => console.log('Running on :3000'));
EOF

# Create package.json
cat > challenges/big-context/package.json << 'EOF'
{
  "name": "roasting-service",
  "version": "2.0.0",
  "main": "src/index.js"
}
EOF

# Simulate a large node_modules directory (don't run real npm install, just fake the size)
mkdir -p challenges/big-context/node_modules/.fake-package
dd if=/dev/zero of=challenges/big-context/node_modules/.fake-package/large-lib.bin bs=1M count=100 2>/dev/null

# Simulate .git history
mkdir -p challenges/big-context/.git/objects
dd if=/dev/zero of=challenges/big-context/.git/objects/pack.bin bs=1M count=150 2>/dev/null

# Simulate an accidentally committed test-data folder
mkdir -p challenges/big-context/test-data
dd if=/dev/zero of=challenges/big-context/test-data/sample-images.bin bs=1M count=100 2>/dev/null

# Create some other common files to ignore
echo "DB_PASSWORD=supersecret123" > challenges/big-context/.env
echo "*.log files" > challenges/big-context/debug.log
```

The Dockerfile is already provided for you — create it:

```bash
cat > challenges/big-context/Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
COPY src/ ./src/
EXPOSE 3000
CMD ["node", "src/index.js"]
EOF
```

Now try a build *without* any `.dockerignore`:

```bash
docker build -t learn-ch02-context-test challenges/big-context/
```

Watch the first line of output. You should see something like:

```
=> transferring context: 350MB+
```

---

## Your Task

1. Create a file called `challenges/big-context/.dockerignore`
2. Add the right patterns to exclude the large directories and sensitive files
3. Build again:

```bash
docker build \
  --progress=plain \
  -t learn-ch02-context-fixed \
  challenges/big-context/
```

4. The first line of the build output should now show transferring context well under 1MB

---

## Requirements

- The `.dockerignore` file must exist at `challenges/big-context/.dockerignore`
- The build context must be under 1MB (the verify script checks the build output)
- The image must still build successfully (the `COPY` instructions in the Dockerfile must still work)
- The `.env` file must be excluded (it contains a fake password — good practice regardless of size)

---

## Hints

<details>
<summary>Hint 1 — General direction</summary>

A `.dockerignore` file works like `.gitignore`. You list patterns of files and directories that Docker should not include when transferring the build context. Look at what's in your `big-context/` directory and figure out which things are large and not needed by the Dockerfile.

The Dockerfile only does `COPY package.json ./` and `COPY src/ ./src/`. Everything else is fair game to exclude.

</details>

<details>
<summary>Hint 2 — Specific patterns</summary>

You need to exclude these four things:
- `node_modules/` — dependencies installed locally are not needed (they get reinstalled during `docker build`)
- `.git/` — version control history is never needed in a Docker image
- `test-data/` — test fixtures have no place in production
- `.env` — environment files may contain secrets and should never be in an image

A `.dockerignore` pattern for a directory just needs to be the directory name, one per line.

</details>

<details>
<summary>Hint 3 — Near-answer guidance</summary>

Your `.dockerignore` file should look something like this:

```
# Dependencies — never needed; Docker installs them fresh
node_modules/

# Version control history
.git

# Test data and fixtures
test-data/

# Secrets and local config
.env
*.env.local

# Build output (if you had a build step)
dist/
build/

# Logs
*.log

# OS-generated files
.DS_Store
Thumbs.db
```

After creating this file, rebuild. The `transferring context` line should drop dramatically. The key insight: `.dockerignore` is applied *before* the context is sent, so Docker never has to inspect or transfer those files.

</details>

---

## Verification

Run the chapter verify script:

```bash
bash curriculum/ch02-image-optimization/challenges/verify.sh
```

Or check manually:

```bash
# Build and capture the context size from the output
docker build --progress=plain -t learn-ch02-context-fixed challenges/big-context/ 2>&1 | grep "transferring context"
```

You're looking for something like:
```
=> transferring context: 843B
```

Under 1MB means under `1048576` bytes (1MB) — or just look for KB or B in the output rather than MB.

---

## Post-Challenge Debrief

Once you pass:

1. **What you did:** You created a `.dockerignore` file that excludes large directories and sensitive files from the Docker build context.

2. **Why it works:** Docker streams the entire build context to the daemon before processing any instructions. Files excluded by `.dockerignore` are never sent — they're filtered at the client before the transfer begins. Smaller context = faster builds regardless of how many `COPY` instructions the Dockerfile has.

3. **Real-world connection:** This matters most in two situations: (1) projects with large `node_modules` or compiled dependencies, and (2) monorepos where the entire repo is large but each service only needs a small slice. Some teams put a `.dockerignore` in every project as a matter of policy.

4. **Interview angle:** "What is the Docker build context and how would you reduce its size?" Tests whether candidates understand what happens when you run `docker build`.

5. **Pro tip:** `.dockerignore` also affects security. Without it, a `.env`, `*.pem`, or `credentials.json` file sitting in the project root can be accidentally included in the image — and then pushed to a registry. Always create a `.dockerignore`. Treat it like a seatbelt: always wear it, regret it if you don't.

# Lesson 1: Dockerfile Deep Dive

## The Scene

"Before we fix the Bean-Tracker image," you say, pulling up a terminal, "let me show you exactly what's happening inside a Dockerfile. Because once you understand what each instruction *does*, the optimization path becomes obvious."

You open a blank file.

"Think of a Dockerfile as a recipe. Each line is an instruction to the chef. And each instruction leaves a trace — a layer — in the final image. Let's go through them one by one."

---

## What Is a Dockerfile?

A Dockerfile is a plain text file with no extension that contains a series of instructions. Docker reads these instructions top to bottom and executes each one to build an image.

```bash
docker build -t my-image:v1 .
```

The `.` at the end is the **build context** — the directory Docker sends to the daemon. We'll talk more about that in Lesson 3.

---

## The Instructions, One by One

### FROM — The Starting Point

Every Dockerfile must begin with `FROM`. It specifies the base image your image is built on.

```dockerfile
FROM ubuntu:24.04
```

```dockerfile
FROM node:20-alpine
```

```dockerfile
FROM scratch
```

`scratch` is special — it's an empty image with nothing in it. Used for building truly minimal images from scratch (pun intended).

**The layer it creates:** A full copy of the base image's filesystem.

**What you should know:** The base image you choose has a massive impact on your final image size. `ubuntu:24.04` is around 70MB. `alpine:3.21` is about 7MB. More on this in Lesson 3.

---

### RUN — Execute Commands During Build

`RUN` executes a command inside the image during the build process. The result is baked into a new layer.

```dockerfile
RUN apt-get update && apt-get install -y curl
```

```dockerfile
RUN npm install
```

```dockerfile
RUN go build -o /app/server .
```

**The layer it creates:** A new layer containing whatever changed on the filesystem after the command ran.

**Important:** `RUN` commands run at *build time*, not at *runtime* when the container starts. If you want something to happen when the container launches, that's `CMD` or `ENTRYPOINT`.

**Pro tip:** Chain related commands with `&&` to keep them in a single layer. We'll go deep on why in Lesson 2.

---

### COPY — Bring Files Into the Image

`COPY` copies files or directories from your build context into the image.

```dockerfile
COPY package.json .
COPY src/ /app/src/
COPY . /app
```

**The layer it creates:** A layer containing the copied files.

**Syntax:** `COPY <source-on-host> <destination-in-image>`

The destination can be an absolute path (`/app/server.js`) or a path relative to the current `WORKDIR`.

---

### ADD — COPY's Older, Fancier Sibling

`ADD` does everything `COPY` does, plus two extras:

1. It can fetch URLs: `ADD https://example.com/file.tar.gz /tmp/`
2. It auto-extracts local `.tar` archives: `ADD archive.tar.gz /app/`

```dockerfile
ADD https://example.com/config.tar.gz /etc/myapp/
```

**When should you use ADD vs COPY?**

Use `COPY` for almost everything. It's explicit and predictable. Use `ADD` only when you specifically need the auto-extract behavior. The automatic URL fetching in `ADD` is generally considered a bad practice — use `RUN curl` or `RUN wget` instead so the step is visible and cacheable.

---

### WORKDIR — Set the Working Directory

`WORKDIR` sets the working directory for any subsequent `RUN`, `COPY`, `ADD`, `CMD`, and `ENTRYPOINT` instructions.

```dockerfile
WORKDIR /app
```

It's like running `mkdir -p /app && cd /app` — except it persists for all following instructions.

**The layer it creates:** A minimal layer (just the directory metadata if it doesn't exist yet).

**Best practice:** Always set a `WORKDIR` early in your Dockerfile. It prevents you from accidentally dumping files into unexpected locations. Never rely on the default working directory.

```dockerfile
FROM node:20-alpine

WORKDIR /app          # All following instructions operate here

COPY package.json .   # Copies to /app/package.json
RUN npm install       # Runs in /app
COPY . .              # Copies everything to /app/
```

---

### ENV — Set Environment Variables

`ENV` sets environment variables that are available both during the build and at runtime inside the container.

```dockerfile
ENV NODE_ENV=production
ENV PORT=8080
ENV DB_HOST=localhost DB_PORT=5432
```

```dockerfile
# Modern multi-variable syntax
ENV NODE_ENV=production \
    PORT=8080 \
    LOG_LEVEL=info
```

You can reference ENV variables later in the Dockerfile with `$VARIABLE_NAME`:

```dockerfile
ENV APP_HOME=/opt/myapp
WORKDIR $APP_HOME
```

**What ENV does NOT do:** It does not hide secrets. Environment variables set with `ENV` are visible in `docker inspect` and embedded in the image. Never put passwords or API keys in `ENV`.

---

### EXPOSE — Document a Port

`EXPOSE` is documentation. It tells the reader (and tools like Docker Compose) which ports the container *intends* to listen on.

```dockerfile
EXPOSE 8080
EXPOSE 8080/udp
```

**What EXPOSE does NOT do:** It does not actually publish or open the port. A container with `EXPOSE 8080` and no `-p` flag in `docker run` is still unreachable from the host. You still need `-p 8080:8080` or `-P` to make it accessible.

Think of it as a hint on the label of the image: "this thing listens on 8080."

---

### CMD — The Default Command

`CMD` defines the default command that runs when a container starts, if no command is specified in `docker run`.

```dockerfile
CMD ["node", "server.js"]
```

```dockerfile
CMD ["python", "-m", "http.server", "8080"]
```

There are three forms of `CMD`:

| Form | Example | Notes |
|------|---------|-------|
| Exec form (preferred) | `CMD ["node", "app.js"]` | Runs directly, no shell |
| Shell form | `CMD node app.js` | Runs via `/bin/sh -c` |
| As default args to ENTRYPOINT | `CMD ["--port", "8080"]` | Used with ENTRYPOINT |

**Prefer the exec form** `["executable", "arg1", "arg2"]`. The shell form wraps your command in `/bin/sh -c`, which means your process gets PID > 1 and Docker signals (like Ctrl+C) may not reach it properly.

**Only the last CMD matters.** If you have multiple `CMD` instructions, only the final one takes effect.

---

### ENTRYPOINT — The Container's Identity

`ENTRYPOINT` defines the executable that always runs when the container starts. Unlike `CMD`, it's much harder to override accidentally.

```dockerfile
ENTRYPOINT ["nginx", "-g", "daemon off;"]
```

```dockerfile
ENTRYPOINT ["python", "app.py"]
```

---

## CMD vs ENTRYPOINT — The Important Difference

This is one of the most commonly confused pairs in Docker. Here's the mental model:

- `ENTRYPOINT` = **what** the container runs (its identity)
- `CMD` = **default arguments** passed to the entrypoint

When used together:

```dockerfile
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["postgres"]
```

The container runs `docker-entrypoint.sh postgres` by default. But you can override the arguments:

```bash
docker run my-image some-other-command
# Runs: docker-entrypoint.sh some-other-command
```

You *can* override `ENTRYPOINT` too, but it requires the explicit `--entrypoint` flag:

```bash
docker run --entrypoint bash my-image
```

**Practical rule of thumb:**

| Use case | Use |
|----------|-----|
| Image wraps a single tool (a database, a web server) | `ENTRYPOINT` |
| General-purpose image where users run arbitrary commands | `CMD` |
| Tool + sensible defaults that users often override | `ENTRYPOINT` + `CMD` together |

---

## Putting It All Together: A Step-by-Step Dockerfile

Let's write a Dockerfile for a simple Node.js API from scratch. We'll build it instruction by instruction.

**Step 1: Choose a base image**

```dockerfile
FROM node:20-alpine
```

We're using the Alpine variant — much smaller than the default `node:20` (Debian-based).

**Step 2: Set the working directory**

```dockerfile
FROM node:20-alpine

WORKDIR /app
```

**Step 3: Copy dependency files and install**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev
```

We copy *only* the package files first. This is the caching trick we'll explain in detail in Lesson 2.

> **Note:** `--omit=dev` skips installing devDependencies, keeping the image lean. (Older tutorials may show `--production`, which was deprecated in npm 9.)

**Step 4: Copy application source**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/
```

**Step 5: Configure the environment**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/

ENV NODE_ENV=production
ENV PORT=3000
```

**Step 6: Document the port**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000
```

**Step 7: Define the startup command**

```dockerfile
FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --omit=dev

COPY src/ ./src/

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["node", "src/server.js"]
```

That's a complete, reasonable Dockerfile. Clean, readable, and with the layer order that makes caching work well.

---

## Seeing the Layers

After building, you can inspect the layers directly:

```bash
docker build -t learn-ch02-demo .

docker image history learn-ch02-demo
```

Output:

```
IMAGE          CREATED          CREATED BY                                      SIZE
a3f7c2b8d1e9   2 minutes ago    CMD ["node" "src/server.js"]                    0B
<missing>      2 minutes ago    EXPOSE map[3000/tcp:{}]                         0B
<missing>      2 minutes ago    ENV PORT=3000                                   0B
<missing>      2 minutes ago    ENV NODE_ENV=production                         0B
<missing>      2 minutes ago    COPY src/ ./src/                               14.2kB
<missing>      2 minutes ago    RUN npm install --omit=dev                    4.1MB
<missing>      2 minutes ago    COPY package*.json ./                           1.8kB
<missing>      2 minutes ago    WORKDIR /app                                    0B
<missing>      2 minutes ago    /bin/sh -c #(nop)  CMD ["node"]                 0B
...            ...              (base image layers)                             ...
```

Notice: instructions like `CMD`, `EXPOSE`, `ENV`, and `WORKDIR` create layers of almost zero size. The real size comes from `RUN` and `COPY` instructions that add actual files.

---

## Quick Reference

| Instruction | Purpose | Creates real layer size? |
|-------------|---------|--------------------------|
| `FROM` | Set base image | Yes (base image files) |
| `RUN` | Execute a command | Yes (files changed) |
| `COPY` | Copy files in | Yes (files added) |
| `ADD` | Copy + extract/fetch | Yes (files added) |
| `WORKDIR` | Set working directory | Minimal |
| `ENV` | Set env variable | Minimal |
| `EXPOSE` | Document a port | No |
| `CMD` | Default command | No |
| `ENTRYPOINT` | Container executable | No |

---

## Try It Yourself

1. Create a new directory called `lesson01-practice`
2. Inside it, create a file called `hello.js` with this content:

```javascript
const http = require('http');
const port = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200);
  res.end('Hello from NoCappuccino!\n');
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
```

3. Create a `package.json`:

```json
{
  "name": "lesson01-practice",
  "version": "1.0.0",
  "main": "hello.js"
}
```

4. Write a Dockerfile using the complete example above (adjusted to your filename)
5. Build it: `docker build -t learn-ch02-lesson01 .`
6. Run it: `docker run -p 3000:3000 --rm --label app=learn-docker-k8s --label chapter=ch02 learn-ch02-lesson01`
7. Test it: `curl http://localhost:3000`
8. Check the layers: `docker image history learn-ch02-lesson01`

---

Ready for Lesson 2? We're going to look at something subtle that trips up almost every developer the first time: why the *order* of your Dockerfile instructions can make the difference between a 30-second build and a 5-minute build.

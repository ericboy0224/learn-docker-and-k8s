# Challenge 5.1: Full Stack

> "Okay, I've got the app code ready. Frontend, backend, Redis, Postgres. Everything's in the `app/` directory. Your mission: make it all run with one command."
> — Sarah

---

## The Situation

Dave just hired two more developers. One of them spent yesterday asking Marcus why the backend was returning 500 errors — turns out he never started Postgres. The other one has been running Redis on port 6380 because something else grabbed 6379, and now the session cache isn't working.

Sarah has had enough.

The entire NoCappuccino application stack is sitting in the `app/` directory of this challenge. Your job is to write a `docker-compose.yml` that brings the whole thing up with a single `docker compose up -d`.

---

## The Stack

You need to run four services:

| Service | Description | Internal Port | Exposed Port |
|---------|-------------|--------------|--------------|
| `frontend` | Nginx serving static HTML | 80 | 8080 |
| `backend` | Node.js API | 3000 | 3000 |
| `redis` | Cache (official image) | 6379 | none |
| `postgres` | Database (official image) | 5432 | none |

All four services must be on a custom network called `app-net`.

The backend needs these environment variables:
- `DATABASE_URL` — `postgres://brew:brewpass@postgres:5432/cloudbrew`
- `REDIS_URL` — `redis://redis:6379`
- `PORT` — `3000`

Postgres needs these environment variables:
- `POSTGRES_DB` — `cloudbrew`
- `POSTGRES_USER` — `brew`
- `POSTGRES_PASSWORD` — `brewpass`

Postgres data must persist in a named volume called `db-data`.

---

## App Code

The application code is provided. Here is what each piece does and what it expects.

### `app/backend/server.js`

```javascript
const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 3000;

// Postgres connection
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Redis connection
const redisClient = redis.createClient({ url: process.env.REDIS_URL });
redisClient.connect().catch(console.error);

// Initialize DB schema
async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS coffees (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100) NOT NULL,
      origin VARCHAR(100),
      created_at TIMESTAMP DEFAULT NOW()
    )
  `);
  console.log('Database schema ready.');
}

// Health endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'backend' });
});

// Get all coffees (with Redis cache)
app.get('/api/coffees', async (req, res) => {
  try {
    const cached = await redisClient.get('coffees');
    if (cached) {
      return res.json({ source: 'cache', data: JSON.parse(cached) });
    }
    const result = await pool.query('SELECT * FROM coffees ORDER BY created_at DESC');
    await redisClient.setEx('coffees', 60, JSON.stringify(result.rows));
    res.json({ source: 'database', data: result.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Add a coffee
app.post('/api/coffees', async (req, res) => {
  try {
    const { name, origin } = req.body;
    const result = await pool.query(
      'INSERT INTO coffees (name, origin) VALUES ($1, $2) RETURNING *',
      [name, origin]
    );
    await redisClient.del('coffees'); // Invalidate cache
    res.status(201).json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

initDb()
  .then(() => {
    app.listen(PORT, () => console.log(`Backend listening on port ${PORT}`));
  })
  .catch(err => {
    console.error('Failed to initialize database:', err.message);
    process.exit(1);
  });
```

### `app/backend/package.json`

```json
{
  "name": "cloudbrew-backend",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo 'Tests would run here' && exit 0"
  },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.3",
    "redis": "^4.6.10"
  }
}
```

### `app/backend/Dockerfile`

```dockerfile
FROM node:20-alpine

LABEL app=learn-docker-k8s
LABEL chapter=ch05

WORKDIR /app

COPY package.json package-lock.json* ./
RUN npm install --omit=dev

COPY server.js ./

EXPOSE 3000

CMD ["node", "server.js"]
```

### `app/frontend/index.html`

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>NoCappuccino — Specialty Coffee</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
           background: #1a0a00; color: #f5e6d0; min-height: 100vh; }
    header { background: #3d1a00; padding: 1.5rem 2rem;
             border-bottom: 2px solid #8b4513; }
    header h1 { font-size: 1.8rem; color: #d4a96a; }
    header p { color: #b07040; margin-top: 0.25rem; }
    main { max-width: 800px; margin: 2rem auto; padding: 0 1rem; }
    .card { background: #2d1500; border: 1px solid #5c3010;
            border-radius: 8px; padding: 1.5rem; margin-bottom: 1.5rem; }
    .card h2 { color: #d4a96a; margin-bottom: 1rem; }
    .form-row { display: flex; gap: 0.75rem; margin-bottom: 0.75rem; flex-wrap: wrap; }
    input { background: #1a0a00; border: 1px solid #5c3010; color: #f5e6d0;
            padding: 0.5rem 0.75rem; border-radius: 4px; flex: 1; min-width: 150px; }
    button { background: #8b4513; color: #f5e6d0; border: none;
             padding: 0.5rem 1.25rem; border-radius: 4px; cursor: pointer; }
    button:hover { background: #a0522d; }
    #coffee-list { list-style: none; }
    #coffee-list li { padding: 0.75rem; border-bottom: 1px solid #3d1a00;
                      display: flex; justify-content: space-between; }
    #coffee-list li:last-child { border-bottom: none; }
    .origin { color: #b07040; font-size: 0.9rem; }
    .status { padding: 0.5rem; border-radius: 4px; font-size: 0.85rem;
              margin-bottom: 1rem; }
    .status.ok { background: #1a3a1a; color: #6fbf6f; border: 1px solid #2d6a2d; }
    .status.error { background: #3a1a1a; color: #bf6f6f; border: 1px solid #6a2d2d; }
    .source-badge { font-size: 0.75rem; padding: 0.2rem 0.5rem;
                    border-radius: 3px; background: #3d2010; color: #d4a96a; }
  </style>
</head>
<body>
  <header>
    <h1>NoCappuccino</h1>
    <p>Specialty Coffee Subscriptions</p>
  </header>
  <main>
    <div class="card">
      <h2>Add a Coffee</h2>
      <div class="form-row">
        <input id="name" placeholder="Coffee name (e.g. Ethiopian Yirgacheffe)" />
        <input id="origin" placeholder="Origin (e.g. Ethiopia)" />
      </div>
      <button onclick="addCoffee()">Add to Catalog</button>
    </div>
    <div class="card">
      <h2>Coffee Catalog <span id="source-badge" class="source-badge" style="display:none"></span></h2>
      <div id="status" class="status" style="display:none"></div>
      <ul id="coffee-list"><li>Loading...</li></ul>
    </div>
  </main>

  <script>
    const API = 'http://localhost:3000';

    async function loadCoffees() {
      const statusEl = document.getElementById('status');
      try {
        const res = await fetch(`${API}/api/coffees`);
        const data = await res.json();
        const badge = document.getElementById('source-badge');
        badge.textContent = data.source === 'cache' ? 'From cache' : 'From database';
        badge.style.display = 'inline';
        statusEl.style.display = 'none';
        const list = document.getElementById('coffee-list');
        if (data.data.length === 0) {
          list.innerHTML = '<li>No coffees yet. Add one above!</li>';
        } else {
          list.innerHTML = data.data.map(c =>
            `<li><span>${c.name}</span><span class="origin">${c.origin || '—'}</span></li>`
          ).join('');
        }
      } catch (err) {
        statusEl.textContent = `Cannot reach backend at ${API}. Is it running?`;
        statusEl.className = 'status error';
        statusEl.style.display = 'block';
        document.getElementById('coffee-list').innerHTML = '';
      }
    }

    async function addCoffee() {
      const name = document.getElementById('name').value.trim();
      const origin = document.getElementById('origin').value.trim();
      if (!name) return;
      await fetch(`${API}/api/coffees`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, origin })
      });
      document.getElementById('name').value = '';
      document.getElementById('origin').value = '';
      loadCoffees();
    }

    loadCoffees();
    setInterval(loadCoffees, 10000);
  </script>
</body>
</html>
```

### `app/frontend/nginx.conf`

```nginx
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### `app/frontend/Dockerfile`

```dockerfile
FROM nginx:1.25-alpine

LABEL app=learn-docker-k8s
LABEL chapter=ch05

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 80
```

---

## Your Task

Create a `docker-compose.yml` file that:

1. Defines all four services (`frontend`, `backend`, `redis`, `postgres`)
2. Builds `frontend` and `backend` from their respective Dockerfiles in `app/`
3. Uses the official `redis:7-alpine` and `postgres:16-alpine` images
4. Sets the required environment variables for `backend` and `postgres`
5. Maps ports: frontend on 8080, backend on 3000
6. Connects all services to a custom network `app-net`
7. Creates a named volume `db-data` for Postgres
8. Uses the project name `learn-ch05` and includes the `app: learn-docker-k8s` and `chapter: ch05` labels on all resources

You do NOT need to add health checks for this challenge (that's Challenge 2).

---

## Success Criteria

Run the verification script when you think you're done:

```bash
bash challenges/verify.sh
```

You should see all four services running:

```
$ docker compose ps
NAME                      STATUS
learn-ch05-frontend-1     running
learn-ch05-backend-1      running
learn-ch05-redis-1        running
learn-ch05-postgres-1     running
```

And the frontend should be accessible:

```bash
curl -sf http://localhost:8080
# Should return HTML with "NoCappuccino" in it
```

And the backend health endpoint:

```bash
curl -sf http://localhost:3000/health
# Should return: {"status":"ok","service":"backend"}
```

---

## Hints

If you're stuck, use these hints one at a time. Try each one before reading the next.

<details>
<summary>Hint 1 — Where to start</summary>

Start with the skeleton structure. Every `docker-compose.yml` begins with:

```yaml
name: learn-ch05

services:
  # your services here

networks:
  # your networks here

volumes:
  # your volumes here
```

For each service, you need at minimum: either `image:` or `build:`, and any required `environment:`, `ports:`, `networks:`, and `volumes:`.

</details>

<details>
<summary>Hint 2 — Build paths and the backend connection issue</summary>

For the `build:` property, the path is relative to where your `docker-compose.yml` lives. If your Compose file is at `challenges/docker-compose.yml` and the backend code is at `app/backend/`, the build path is `../app/backend`.

Also remember: inside the Docker network, services find each other by service name. The backend connects to `postgres` (the service name), not `localhost`. The environment variable should be:

```
DATABASE_URL: postgres://brew:brewpass@postgres:5432/cloudbrew
```

</details>

<details>
<summary>Hint 3 — Volume syntax and network attachment</summary>

Named volumes require two things: the mount inside the service definition, and the declaration at the top level.

```yaml
services:
  postgres:
    volumes:
      - db-data:/var/lib/postgresql/data  # mount the named volume

volumes:
  db-data:                                # declare it exists
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

Every service that needs to communicate with another service must be on the same network. Both the service definition and the network itself need to be defined:

```yaml
services:
  backend:
    networks:
      - app-net

networks:
  app-net:
    labels:
      app: learn-docker-k8s
      chapter: ch05
```

</details>

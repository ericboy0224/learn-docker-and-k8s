const express = require('express');
const { Pool } = require('pg');
const redis = require('redis');

const app = express();
app.use(express.json());

// Allow cross-origin requests from the frontend
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

const PORT = process.env.PORT || 3000;

// Postgres connection
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

// Redis connection
const redisClient = redis.createClient({ url: process.env.REDIS_URL });

redisClient.on('error', (err) => console.error('Redis client error:', err));
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

// Health endpoint — used by Docker health checks and load balancers
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'backend' });
});

// Get all coffees — checks Redis cache first, falls back to Postgres
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
    console.error('GET /api/coffees error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Add a coffee — invalidates the Redis cache
app.post('/api/coffees', async (req, res) => {
  try {
    const { name, origin } = req.body;
    if (!name) {
      return res.status(400).json({ error: 'name is required' });
    }
    const result = await pool.query(
      'INSERT INTO coffees (name, origin) VALUES ($1, $2) RETURNING *',
      [name, origin || null]
    );
    await redisClient.del('coffees'); // Invalidate cache
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('POST /api/coffees error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

initDb()
  .then(() => {
    app.listen(PORT, () => {
      console.log(`NoCappuccino backend listening on port ${PORT}`);
      console.log(`  Database: ${process.env.DATABASE_URL ? 'configured' : 'NOT SET'}`);
      console.log(`  Redis:    ${process.env.REDIS_URL ? 'configured' : 'NOT SET'}`);
    });
  })
  .catch((err) => {
    console.error('Failed to initialize database:', err.message);
    process.exit(1);
  });

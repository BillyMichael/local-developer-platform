import express from 'express';
import pg from 'pg';
import * as Minio from 'minio';

const app = express();
const port = 3000;

// PostgreSQL Configuration
const pool = new pg.Pool({
  user: process.env.DB_USER || 'postgres',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  port: 5432,
});

// MinIO Configuration
const minioClient = new Minio.Client({
  endPoint: process.env.MINIO_ENDPOINT || 'localhost',
  port: parseInt(process.env.MINIO_PORT || '9000'),
  useSSL: process.env.MINIO_USE_SSL === 'true',
  accessKey: process.env.MINIO_ACCESS_KEY || 'minioadmin',
  secretKey: process.env.MINIO_SECRET_KEY || 'minioadmin',
});

app.get('/api/data', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    // Example: List buckets from MinIO
    let buckets = [];
    try {
        buckets = await minioClient.listBuckets();
    } catch (minioErr) {
        console.warn('Could not list MinIO buckets:', minioErr.message);
        buckets = [{ name: 'Error connecting to MinIO', error: minioErr.message }];
    }

    res.json({ 
      message: 'Hello from Backend!', 
      db_time: result.rows[0].now,
      minio_buckets: buckets
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

app.listen(port, () => {
  console.log(`Backend listening on port ${port}`);
});

const express = require("express");
const { Pool } = require("pg");
const path = require("path");

const app = express();
const port = process.env.PORT || 3000;

// Enable SSL only when connecting to AWS RDS (RDS PostgreSQL 15 rejects
// unencrypted connections). Local Docker Compose keeps working without SSL.
const useSSL = (process.env.DATABASE_URL || "").includes("rds.amazonaws.com");

// Setup PostgreSQL connection pool using environment variables
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: useSSL ? { rejectUnauthorized: false } : false,
});

app.use(express.json());
app.use(express.static(path.join(__dirname, "../public")));

// API Route to record a visit and get total count
app.get("/api/visits", async (req, res) => {
  try {
    await pool.query("INSERT INTO visits DEFAULT VALUES");
    const result = await pool.query("SELECT COUNT(*) FROM visits");
    res.json({ totalVisits: result.rows[0].count });
  } catch (err) {
    console.error("Database query error:", err);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Initialize database table first, then start the server
async function startServer() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS visits (
        id SERIAL PRIMARY KEY,
        visited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log("Database table verified successfully.");

    app.listen(port, () => {
      console.log(`Server is running on port ${port}`);
    });
  } catch (err) {
    console.error("Error initializing database:", err);
    process.exit(1);
  }
}

startServer();

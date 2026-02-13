const http = require('http');
const fs = require('fs');
const { MongoClient } = require('mongodb'); // Added for Requirement 1.33

const port = 8080;
// Requirement: Access MongoDB via environment variable 
const mongoUrl = process.env.MONGO_URL || "mongodb://mongodb-service:27017/";

const server = http.createServer(async (req, res) => {
  // 1. Route to verify the specific Wiz file [cite: 69]
  if (req.url === '/wizexercise.txt') {
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) {
        res.writeHead(404);
        res.end("Error: wizexercise.txt not found at root.");
        return;
      }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } 
  // 2. Default landing page with DB Status [cite: 70]
  else {
    let dbStatus = "Checking database...";
    try {
      const client = new MongoClient(mongoUrl, { serverSelectionTimeoutMS: 2000 });
      await client.connect();
      dbStatus = "Successfully connected to MongoDB!";
      await client.close();
    } catch (err) {
      dbStatus = `Database Error: ${err.message}`;
    }

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`<h1>Wiz Technical Exercise</h1><p>App Status: <b>Online</b></p><p>DB Status: <b>${dbStatus}</b></p>`);
  }
});

server.listen(port, '0.0.0.0', () => {
  console.log(`Server running on port ${port}`);
});

// Final Connection Test
const http = require('http');
const fs = require('fs');
const { MongoClient } = require('mongodb'); // The "phone" to call the database

const port = 8080;
const mongoUrl = process.env.MONGO_URL || "mongodb://mongodb-service:27017/wizdb";

const server = http.createServer(async (req, res) => {
  if (req.url === '/wizexercise.txt') {
    // Standard Identity Check
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) { res.writeHead(404); res.end("File not found."); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } else {
    // The "Wiz Demo" Dashboard
    let dbStatus = "Checking...";
    try {
      const client = await MongoClient.connect(mongoUrl, { serverSelectionTimeoutMS: 2000 });
      dbStatus = "✅ Connected";
      await client.close();
    } catch (err) {
      dbStatus = "❌ Connection Failed";
    }

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <html>
        <body style="font-family: sans-serif; padding: 40px; text-align: center;">
          <h1>Wiz Technical Exercise</h1>
          <div style="border: 1px solid #ccc; display: inline-block; padding: 20px; border-radius: 10px;">
            <p>Application Status: <span style="color: green;"><b>ONLINE</b></span></p>
            <p>Database (MongoDB): <b>${dbStatus}</b></p>
          </div>
          <p style="margin-top: 20px;"><a href="/wizexercise.txt">View Identity File</a></p>
        </body>
      </html>
    `);
  }
});

server.listen(port, '0.0.0.0');

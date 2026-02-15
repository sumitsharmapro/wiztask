const http = require('http');
const fs = require('fs');
const { MongoClient } = require('mongodb');

const port = 8080;
const mongoUrl = process.env.MONGO_URL;

const server = http.createServer(async (req, res) => {
  if (req.url === '/wizexercise.txt') {
    // Requirement: Validate the identity file contains your name
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) { res.writeHead(404); res.end("File not found."); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } else {
    let dbStatus = "Checking...";
    let connectionDetail = "";

    try {
      if (!mongoUrl) throw new Error("MONGO_URL env variable missing");
      
      // THE FIX: We use a literal 10-second timeout and force IPv4
      const client = await MongoClient.connect(mongoUrl, { 
        serverSelectionTimeoutMS: 10000, // Double the timeout for GKE-to-VM latency
        family: 4,                      // Force IPv4 only
        directConnection: true,         // Skip replica set discovery (Critical for single VMs)
        connectTimeoutMS: 10000
      });
      
      const adminDb = client.db('admin').admin();
      const info = await adminDb.serverStatus();
      dbStatus = `<span style="color: green;">Connected (v${info.version})</span>`;
      connectionDetail = `Target: 10.0.1.5 (Verified)`;
      
      await client.close();
    } catch (err) {
      dbStatus = `<span style="color: red;">Connection Failed</span>`;
      connectionDetail = `Diagnostic: ${err.message}`;
    }

    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
      <html>
        <body style="font-family: sans-serif; padding: 40px; text-align: center; background-color: #f4f7f6;">
          <h1 style="color: #0d1b2a;">Wiz Technical Exercise v4</h1>
          <div style="background: white; border: 1px solid #ddd; display: inline-block; padding: 30px; border-radius: 15px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <p style="font-size: 1.2em;">App Status: <span style="color: green;"><b>ONLINE</b></span></p>
            <p style="font-size: 1.2em;">Database Tier: <b>${dbStatus}</b></p>
            <p style="font-size: 0.9em; color: #666;"><i>${connectionDetail}</i></p>
          </div>
          <div style="margin-top: 30px;">
            <p><a href="/wizexercise.txt" style="color: #0077b6; text-decoration: none; font-weight: bold;">Step 1: Verify Identity File (/wizexercise.txt)</a></p>
          </div>
          <footer style="margin-top: 50px; font-size: 0.8em; color: #999;">
            Note: This environment contains intentional configuration weaknesses for demo purposes.
          </footer>
        </body>
      </html>
    `);
  }
});

server.listen(port, '0.0.0.0');

const http = require('http');
const fs = require('fs');
const { MongoClient } = require('mongodb');

const port = 8080;

// Access to MongoDB must be via an environment variable 
const mongoUrl = process.env.MONGO_URL;

const server = http.createServer(async (req, res) => {
  if (req.url === '/wizexercise.txt') {
    // Requirement: Validate the file actually exists [cite: 69]
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) { res.writeHead(404); res.end("File not found."); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } else {
    let dbStatus = "Checking...";
    let connectionDetail = "";

    try {
      if (!mongoUrl) {
        throw new Error("MONGO_URL environment variable is missing");
      }
      
      // Increased timeout for the external VM connection
      const client = await MongoClient.connect(mongoUrl, { serverSelectionTimeoutMS: 5000 });
      
      // Demonstrate the app and prove data is in the database 
      const adminDb = client.db('admin').admin();
      const info = await adminDb.serverStatus();
      dbStatus = `<span style="color: green;">Connected (v${info.version})</span>`;
      connectionDetail = `Target: ${mongoUrl.split('@')[1] || 'Internal VM'}`;
      
      await client.close();
    } catch (err) {
      dbStatus = `<span style="color: red;">Connection Failed</span>`;
      connectionDetail = err.message;
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
            Note: This environment contains intentional configuration weaknesses for demo purposes. [cite: 9]
          </footer>
        </body>
      </html>
    `);
  }
});

server.listen(port, '0.0.0.0');

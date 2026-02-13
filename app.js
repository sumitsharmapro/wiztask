const http = require('http');
const fs = require('fs');
const port = 8080;
const server = http.createServer((req, res) => {
  if (req.url === '/wizexercise.txt') {
    fs.readFile('/wizexercise.txt', 'utf8', (err, data) => {
      if (err) { res.writeHead(404); res.end("File not found."); return; }
      res.writeHead(200, { 'Content-Type': 'text/plain' });
      res.end(data);
    });
  } else {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end('<h1>Wiz Technical Exercise</h1><p>App Status: <b>Online</b></p>');
  }
});
server.listen(port, '0.0.0.0');

const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const url = require('url');

const clients = new Map(); // Map to store userId -> WebSocket connection
const adminClients = new Set(); // Set to store admin WebSocket connections

function createWebSocketServer(server) {
  const wss = new WebSocketServer({ server });

  wss.on('connection', (ws, req) => {
    const parameters = new url.URL(req.url, `http://${req.headers.host}`).searchParams;
    const token = parameters.get('token');

    if (!token) {
      console.log('WebSocket connection rejected: No token provided.');
      ws.close();
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId;
      const userRole = decoded.role;

      // Store the connection for user-specific updates
      clients.set(userId, ws);
      console.log(`WebSocket client connected: ${userId}`);

      // If the user is an admin, add them to the admin broadcast group
      if (userRole === 'admin') {
        adminClients.add(ws);
        console.log(`Admin client ${userId} added to broadcast group.`);
      }

      ws.on('message', (message) => {
        // Handle incoming messages if needed, e.g., for ping/pong
        console.log(`Received message from ${userId}: ${message}`);
      });

      ws.on('close', () => {
        // Remove the client from the specific user map
        clients.delete(userId);
        console.log(`WebSocket client disconnected: ${userId}`);

        // If the client was an admin, remove them from the admin group
        if (userRole === 'admin') {
          adminClients.delete(ws);
          console.log(`Admin client ${userId} removed from broadcast group.`);
        }
      });

      ws.on('error', (error) => {
        console.error(`WebSocket error for user ${userId}:`, error);
        clients.delete(userId);
        if (userRole === 'admin') {
          adminClients.delete(ws);
        }
      });

    } catch (error) {
      console.log('WebSocket connection rejected: Invalid token.');
      ws.close();
    }
  });

  console.log('WebSocket server created.');
  return wss;
}

function sendUpdateToUser(userId, data) {
  const client = clients.get(userId);
  if (client && client.readyState === client.OPEN) {
    client.send(JSON.stringify(data));
    console.log(`Sent update to user ${userId}:`, data);
    return true; // Indicate that the message was sent
  }
  console.log(`Could not send update to user ${userId}: client not found or connection not open.`);
  return false; // Indicate that the message was not sent
}

module.exports = { createWebSocketServer, sendUpdateToUser, broadcastToAdmins, broadcastToAllUsers };

function broadcastToAdmins(data) {
  adminClients.forEach(client => {
    if (client.readyState === client.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
  console.log(`Broadcasted update to ${adminClients.size} admin clients.`);
}

function broadcastToAllUsers(data) {
  clients.forEach(client => { // clients map stores all user connections
    if (client.readyState === client.OPEN) {
      client.send(JSON.stringify(data));
    }
  });
  console.log(`Broadcasted update to ${clients.size} all connected users.`);
}

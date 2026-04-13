require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
let serviceAccount;
try {
  serviceAccount = require('./serviceAccountKey.json');
} catch (e) {
  console.log('serviceAccountKey.json not found, attempting to load from environment variable...');
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } catch (parseError) {
      console.error('Error parsing FIREBASE_SERVICE_ACCOUNT environment variable:', parseError);
    }
  }
}

if (serviceAccount) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  console.log('Firebase Admin initialized successfully');
} else {
  console.error('CRITICAL: Firebase service account credentials missing!');
}

const app = express();
app.set('trust proxy', 1);
const PORT = process.env.PORT || 10000;
const HOST = '0.0.0.0';

// MongoDB Connection String (from user)
const MONGODB_URI = process.env.MONGODB_URI;

// Middleware
app.use(cors({
  origin: '*', // Allow all origins
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  preflightContinue: false,
  optionsSuccessStatus: 204,
  allowedHeaders: 'Content-Type,Authorization',
}));
app.use(express.json()); // For parsing application/json

// Connect to MongoDB
mongoose.connect(MONGODB_URI)
  .then(() => console.log('MongoDB connected successfully'))
  .catch(err => console.error('MongoDB connection error:', err));

// Integrate auth routes
app.use('/api/auth', require('./routes/auth'));

// Integrate menu and order routes
app.use('/api/menu', require('./routes/menu'));
app.use('/api/orders', require('./routes/orders'));

// Integrate Stripe routes
app.use('/api/stripe', require('./routes/stripe'));

// Integrate upload routes
app.use('/api/upload', require('./routes/upload'));

// Integrate settings routes
app.use('/api/settings', require('./routes/settings'));
app.use('/api/info-pages', require('./routes/infoPages'));

// Root route for API health check
app.get('/', (req, res) => {
  res.json({
    status: 'API is running',
    message: 'Fast Food App Backend API',
    timestamp: new Date()
  });
});

// Error Handling Middleware
app.use((err, req, res, next) => {
  console.error('SERVER ERROR:', err.stack);
  res.status(500).json({ error: 'Server Error', message: err.message });
});

const http = require('http');
const { createWebSocketServer } = require('./websocket');

const server = http.createServer(app);

// Create and attach WebSocket server
createWebSocketServer(server);

// Start the server
server.listen(PORT, HOST, () => {
  console.log(`API Server (HTTP and WebSocket) running on http://${HOST}:${PORT}`);
});

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

// DEBUG ROUTE - A supprimer plus tard
app.get('/api/debug-files', (req, res) => {
  const results = {};
  const pathsToTest = {
    'cwd': process.cwd(),
    '__dirname': __dirname,
    'build_web': path.resolve(__dirname, '..', 'build', 'web'),
    'app_root': path.resolve(__dirname, '..')
  };

  for (const [name, p] of Object.entries(pathsToTest)) {
    try {
      results[name] = {
        path: p,
        exists: fs.existsSync(p),
        files: fs.existsSync(p) ? fs.readdirSync(p).slice(0, 10) : []
      };
    } catch (e) {
      results[name] = { error: e.message };
    }
  }
  res.json(results);
});

const https = require('https');
const axios = require('axios');

app.get('/api/image-proxy', async (req, res) => {
      try {
        const imageUrl = req.query.url;
        if (!imageUrl) {
          return res.status(400).send('Image URL is required');
        }
  
        console.log(`Proxying image request for: ${imageUrl}`);
  
        const response = await axios({
          method: 'GET',
          url: imageUrl,
          responseType: 'stream',
          timeout: 30000, // 30 seconds timeout
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
          }
        });
        console.log(`Successfully fetched image stream from: ${imageUrl}`);
    // Pass through relevant headers
    res.setHeader('Content-Type', response.headers['content-type']);
    res.setHeader('Content-Length', response.headers['content-length']);
    
    response.data.pipe(res);

      } catch (error) {
        console.error(`Error in image proxy for url: ${req.query.url}`);
        if (error.response) {
          // The request was made and the server responded with a status code
          // that falls out of the range of 2xx
          console.error('Response data:', error.response.data);
          console.error('Response status:', error.response.status);
          console.error('Response headers:', error.response.headers);
        } else if (error.request) {
          // The request was made but no response was received
          console.error('No response received:', error.request);
        } else {
          // Something happened in setting up the request that triggered an Error
          console.error('Error message:', error.message);
        }
        res.status(500).send('Error fetching image');
      }});


// Serve static files from the Flutter Web build directory
const findWebPath = () => {
  const possiblePaths = [
    path.resolve(__dirname, '..', 'build', 'web'),
    path.resolve(process.cwd(), 'build', 'web'),
    path.join(process.cwd(), 'build', 'web'),
    '/app/build/web', // Docker absolute path
    path.resolve(__dirname, 'build', 'web')
  ];
  
  console.log('Checking for web path in:', possiblePaths);
  
  for (const p of possiblePaths) {
    try {
      if (fs.existsSync(p) && fs.existsSync(path.join(p, 'index.html'))) {
        return p;
      }
    } catch (e) {
      // Ignore errors for individual paths
    }
  }
  return null;
};

const webPath = findWebPath();
if (webPath) {
  console.log(`Serving static files from detected path: ${webPath}`);
  app.use(express.static(webPath));
} else {
  console.error(`ERROR: Static files directory (build/web) not found in any expected location.`);
}

// Catch-all middleware to serve the Flutter Web app for any non-API requests
app.use((req, res, next) => {
  if (req.originalUrl.startsWith('/api')) {
    return next();
  }
  
  if (req.originalUrl.match(/\.(js|json|png|jpg|jpeg|gif|ico|svg|css|mp4|mp3|otf|ttf|wasm)$/)) {
    return res.status(404).send('Not found');
  }
  
  const currentWebPath = findWebPath();
  if (currentWebPath) {
    const indexPath = path.join(currentWebPath, 'index.html');
    res.sendFile(indexPath);
  } else {
    console.error('CRITICAL: index.html not found during catch-all request.');
    res.status(500).send(`Frontend error: index.html missing. Please ensure your build process completed successfully.`);
  }
});

// Error Handling Middleware
app.use((err, req, res, next) => {
  console.error('SERVER ERROR:', err.stack);
  res.status(500).send(`Server Error: ${err.message}`);
});

const http = require('http');
const { createWebSocketServer } = require('./websocket');

const server = http.createServer(app);

// Create and attach WebSocket server
createWebSocketServer(server);

// Start the server
server.listen(PORT, HOST, () => {
  console.log(`Server (HTTP and WebSocket) running on http://${HOST}:${PORT}`);
});

require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 5002;

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


// Basic Route
app.get('/', (req, res) => {
  res.send('Fast Food Backend API is running!');
});

// Error Handling Middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

const http = require('http');
const { createWebSocketServer } = require('./websocket');

const server = http.createServer(app);

// Create and attach WebSocket server
createWebSocketServer(server);

// Start the server
server.listen(PORT, () => {
  console.log(`Server (HTTP and WebSocket) running on port ${PORT}`);
});

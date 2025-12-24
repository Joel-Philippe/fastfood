const express = require('express');
const router = express.Router();
const RestaurantSettings = require('../models/RestaurantSettings');
const authMiddleware = require('../middleware/authMiddleware');
const authorizeRoles = require('../middleware/authorizeRoles');
const { broadcastToAllUsers } = require('../websocket'); // Import broadcastToAllUsers

// GET restaurant settings
// This is a public route so the frontend can check opening hours
router.get('/', async (req, res) => {
  try {
    // Find the single settings document, or create it if it doesn't exist
    let settings = await RestaurantSettings.findById('main_settings');
    if (!settings) {
      settings = await new RestaurantSettings().save();
    }
    res.json(settings);
  } catch (err) {
    console.error('Error fetching settings:', err);
    res.status(500).send('Server Error');
  }
});

// POST (update/upsert) restaurant settings (Admin only)
router.post('/', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  const { hours } = req.body;

  try {
    // Use findByIdAndUpdate with upsert:true to create the document if it doesn't exist
    const updatedSettings = await RestaurantSettings.findByIdAndUpdate(
      'main_settings',
      { hours },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );
    broadcastToAllUsers({ type: 'SETTINGS_UPDATED', settings: updatedSettings.toObject() }); // Notify all users about settings update
    res.json(updatedSettings);
  } catch (err) {
    console.error('Error updating settings:', err);
    res.status(500).send('Server Error');
  }
});

module.exports = router;

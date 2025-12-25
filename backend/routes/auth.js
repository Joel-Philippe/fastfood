const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const User = require('../models/User'); // Make sure the path is correct
const authMiddleware = require('../middleware/authMiddleware'); // ADDED: Import authMiddleware

const router = express.Router();

// --- Registration Route (optional, to create the first admin) ---
// POST /api/auth/register
router.post(
  '/register',
  [
    body('email', 'Please include a valid email').isEmail(),
    body('password', 'Password must be 6 or more characters').isLength({ min: 6 }),
    body('name').optional().isString(), // Allow optional name field
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { email, password, name } = req.body; // Destructure name

      // Check if user already exists
      let user = await User.findOne({ email });
      if (user) {
        return res.status(400).json({ message: 'User already exists' });
      }

      const hashedPassword = await bcrypt.hash(password, 12);
      user = new User({ email, password: hashedPassword, name }); // Save name
      await user.save();
      res.status(201).json({ message: 'User created successfully' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error during registration' });
    }
  }
);

// --- Create Admin Route (Temporary for setup) ---
// POST /api/auth/create-admin
router.post(
  '/create-admin',
  [
    body('email', 'Please include a valid email').isEmail(),
    body('password', 'Password must be 6 or more characters').isLength({ min: 6 }),
  ],
  async (req, res) => {
    // Only allow admin creation if environment variable is set (for development/initial setup)
    if (process.env.ALLOW_ADMIN_CREATION !== 'true') {
      return res.status(403).json({ message: 'Admin creation is not allowed.' });
    }

    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { email, password } = req.body;

      let user = await User.findOne({ email });
      if (user) {
        return res.status(400).json({ message: 'User already exists' });
      }

      const hashedPassword = await bcrypt.hash(password, 12);
      user = new User({ email, password: hashedPassword, role: 'admin' }); // Set role to admin
      await user.save();
      res.status(201).json({ message: 'Admin user created successfully' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error during admin creation' });
    }
  }
);

// --- Login Route ---
// POST /api/auth/login
router.post(
  '/login',
  [
    body('email', 'Please include a valid email').isEmail(),
    body('password', 'Password is required').exists(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { email, password } = req.body;

      const user = await User.findOne({ email });
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }

      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(400).json({ message: 'Invalid credentials' });
      }

      const token = jwt.sign(
        { userId: user._id, role: user.role, userName: user.name }, // Include userName in JWT payload
        process.env.JWT_SECRET, // Use the secret from environment variables
        { expiresIn: '1h' } // Token expires in 1 hour
      );

      res.json({ token });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error during login' });
    }
  }
);

// PATCH /api/auth/fcm-token - Update FCM token for the logged-in user
router.patch(
  '/fcm-token',
  authMiddleware,
  [
    body('fcmToken', 'FCM token is required').not().isEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const { fcmToken } = req.body;
      const userId = req.userData.userId; // From authMiddleware

      const user = await User.findById(userId);
      if (!user) {
        return res.status(404).json({ message: 'User not found' });
      }

      user.fcmToken = fcmToken;
      await user.save();

      res.json({ message: 'FCM token updated successfully' });
    } catch (error) {
      console.error(error);
      res.status(500).json({ message: 'Server error while updating FCM token' });
    }
  }
);

module.exports = router;

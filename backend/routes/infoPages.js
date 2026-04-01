const express = require('express');
const router = express.Router();
const InfoPage = require('../models/InfoPage');
const authMiddleware = require('../middleware/authMiddleware');
const authorizeRoles = require('../middleware/authorizeRoles');

// GET all visible info pages (Public)
router.get('/', async (req, res) => {
  try {
    const pages = await InfoPage.find({ isVisible: true }).sort('order');
    res.json(pages);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// GET all pages (Admin)
router.get('/admin', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const pages = await InfoPage.find().sort('order');
    res.json(pages);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// POST new page (Admin)
router.post('/', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  const page = new InfoPage(req.body);
  try {
    const newPage = await page.save();
    res.status(201).json(newPage);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// PUT update page (Admin)
router.put('/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const updatedPage = await InfoPage.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.json(updatedPage);
  } catch (err) {
    res.status(400).json({ message: err.message });
  }
});

// DELETE page (Admin)
router.delete('/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    await InfoPage.findByIdAndDelete(req.params.id);
    res.json({ message: 'Page deleted' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;

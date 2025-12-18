const express = require('express');
const router = express.Router();
const multer = require('multer');
const cloudinary = require('cloudinary').v2;
const authMiddleware = require('../middleware/authMiddleware');
const authorizeRoles = require('../middleware/authorizeRoles');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Configure Multer for in-memory storage
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// POST /api/upload/image - Upload image to Cloudinary
router.post(
  '/image',
  authMiddleware,
  authorizeRoles('admin'),
  upload.single('image'), // 'image' is the field name for the file
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: 'No image file provided.' });
      }

      // Upload image to Cloudinary
      const b64 = Buffer.from(req.file.buffer).toString("base64");
      let dataURI = "data:" + req.file.mimetype + ";base64," + b64;
      const result = await cloudinary.uploader.upload(dataURI, {
        folder: 'fast-food-app', // Optional: specify a folder in Cloudinary
      });

      res.status(200).json({ imageUrl: result.secure_url });
    } catch (error) {
      console.error('Error uploading image to Cloudinary:', error);
      res.status(500).json({ message: 'Image upload failed.', error: error.message });
    }
  }
);

module.exports = router;
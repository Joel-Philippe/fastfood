const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const cloudinary = require('cloudinary').v2;
const MenuItem = require('../models/MenuItem');
const MenuCategory = require('../models/MenuCategory');
const Option = require('../models/Option');
const authMiddleware = require('../middleware/authMiddleware');

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});
const authorizeRoles = require('../middleware/authorizeRoles');
const upload = require('../middleware/upload'); // Import upload middleware
const { broadcastToAllUsers } = require('../websocket'); // Import broadcastToAllUsers

// PUT (update) category background image (Admin only)
router.put(
  '/categories/:id/background-image',
  authMiddleware,
  authorizeRoles('admin'),
  upload.single('image'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res.status(400).json({ message: 'No image file provided.' });
      }

      // Upload image to Cloudinary
      const b64 = Buffer.from(req.file.buffer).toString("base64");
      let dataURI = "data:" + req.file.mimetype + ";base64," + b64;
      const result = await cloudinary.uploader.upload(dataURI, {
        folder: 'fast-food-app-categories',
      });

      const updatedCategory = await MenuCategory.findByIdAndUpdate(
        req.params.id,
        { backgroundImageUrl: result.secure_url },
        { new: true }
      );

      if (!updatedCategory) {
        return res.status(404).json({ message: 'Category not found' });
      }

      broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
      res.json(updatedCategory);
    } catch (err) {
      console.error(err.message);
      res.status(500).send('Server Error');
    }
  }
);

// --- Menu Categories Routes ---

// GET all categories
router.get('/categories', async (req, res) => {
  try {
    const categories = await MenuCategory.find();
    res.json(categories);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// POST a new category (Admin only)
router.post(
  '/categories',
  authMiddleware,
  authorizeRoles('admin'),
  upload.single('image'), // Use upload middleware for single image
  [
    body('name', 'Name is required').not().isEmpty(),
    body('type', 'Type is required').not().isEmpty(),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, type, fontColor, backgroundColor } = req.body;
    let backgroundImageUrl;

    try {
      // Handle image upload to Cloudinary if a file is provided
      if (req.file) {
        const b64 = Buffer.from(req.file.buffer).toString("base64");
        const dataURI = "data:" + req.file.mimetype + ";base64," + b64;
        const result = await cloudinary.uploader.upload(dataURI, {
          folder: 'fast-food-app-categories',
        });
        backgroundImageUrl = result.secure_url;
      }

      const newCategory = new MenuCategory({
        name,
        type,
        fontColor,
        backgroundColor,
        backgroundImageUrl, // Add the image URL
      });

      const category = await newCategory.save();
      broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users
      res.status(201).json(category);
    } catch (err) {
      if (err.code === 11000) {
        return res.status(400).json({ message: 'Ce type de catégorie existe déjà.' });
      }
      console.error('Error creating category:', err);
      res.status(500).send('Server Error');
    }
  }
);

// PUT (update) a category (Admin only)
router.put('/categories/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  const { name, type, fontColor, backgroundColor } = req.body;
  const updatedFields = { name, type, fontColor, backgroundColor };

  // Remove undefined fields
  Object.keys(updatedFields).forEach(key => updatedFields[key] === undefined && delete updatedFields[key]);

  try {
    const category = await MenuCategory.findByIdAndUpdate(req.params.id, updatedFields, { new: true });
    if (!category) {
      return res.status(404).json({ message: 'Category not found' });
    }
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json(category);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// DELETE a category (Admin only)
router.delete('/categories/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const category = await MenuCategory.findByIdAndDelete(req.params.id);
    if (!category) {
      return res.status(404).json({ message: 'Category not found' });
    }
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json({ message: 'Category deleted' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// --- Menu Items Routes ---

// GET all menu items (can filter by category)
router.get('/', async (req, res) => {
  try {
    const query = {};
    if (req.query.category) {
      // Use a case-insensitive regular expression for category matching
      query.category = new RegExp(`^${req.query.category}$`, 'i');
    }
    // Removed .populate() calls as they are no longer in the schema
    const menuItems = await MenuItem.find(query);
    res.json(menuItems);
  } catch (err) {
    console.error('Error in GET /api/menu:', err.message);
    res.status(500).json({ message: err.message });
  }
});

// GET a single menu item by ID
router.get('/:id', async (req, res) => {
  try {
    // Removed .populate() calls as they are no longer in the schema
    const menuItem = await MenuItem.findById(req.params.id);

    if (!menuItem) {
      return res.status(404).json({ message: 'Menu item not found' });
    }
    res.json(menuItem);
  } catch (err) {
    console.error('Error in GET /api/menu/:id:', err.message);
    res.status(500).json({ message: err.message });
  }
});


// POST a new menu item (Admin only)
router.post(
  '/',
  authMiddleware,
  authorizeRoles('admin'),
  body('name', 'Name is required').not().isEmpty(),
  body('price', 'Price is required').isNumeric(),
  body('category', 'Category is required').not().isEmpty(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    // Use the new flexible optionTypes field
    const {
      name,
      description,
      price,
      imageUrl,
      category,
      optionTypes,
      removableIngredients,
    } = req.body;

    try {
      const newMenuItem = new MenuItem({
        name,
        description,
        price,
        imageUrl,
        category,
        optionTypes: optionTypes || [], // Use the new field
        removableIngredients: removableIngredients || [],
      });

      const menuItem = await newMenuItem.save();
      broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
      res.status(201).json(menuItem); // Use 201 for resource creation
    } catch (err) {
      console.error('Error creating menu item:', err); // Log the full error object
      res.status(500).send('Server Error');
    }
  }
);

// PUT (update) a menu item (Admin only)
router.put('/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    // Use the new flexible optionTypes field
    const {
      name,
      description,
      price,
      imageUrl,
      category,
      optionTypes,
      removableIngredients,
    } = req.body;

    const updatedFields = {
      name,
      description,
      price,
      imageUrl,
      category,
      optionTypes,
      removableIngredients,
    };

    // Remove undefined fields to avoid setting them to null if not provided in req.body
    Object.keys(updatedFields).forEach(key => updatedFields[key] === undefined && delete updatedFields[key]);

    const menuItem = await MenuItem.findByIdAndUpdate(req.params.id, updatedFields, { new: true });
    if (!menuItem) return res.status(404).json({ message: 'Menu item not found' });
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json(menuItem);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// DELETE a menu item (Admin only)
router.delete('/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const menuItem = await MenuItem.findByIdAndDelete(req.params.id);
    if (!menuItem) return res.status(404).json({ message: 'Menu item not found' });
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json({ message: 'Menu item deleted' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// --- Options Routes (for menu customization) ---

// GET all unique option types
router.get('/options/types', async (req, res) => {
  try {
    const types = await Option.distinct('type');
    res.json(types);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// GET all options
router.get('/options', async (req, res) => {
  try {
    const options = await Option.find();
    res.json(options);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// GET options by type
router.get('/options/:type', async (req, res) => {
  try {
    const options = await Option.find({ type: req.params.type });
    res.json(options);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// POST a new option (Admin only)
router.post(
  '/options',
  [authMiddleware, authorizeRoles('admin'), [body('name', 'Name is required').not().isEmpty(), body('type', 'Type is required').not().isEmpty()]],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const { name, type, imageUrl, price } = req.body;

    try {
      const newOption = new Option({
        name,
        type,
        imageUrl,
        price,
      });

      const option = await newOption.save();
      broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
      res.json(option);
    } catch (err) {
      console.error(err.message);
      res.status(500).send('Server Error');
    }
  }
);

// PUT (update) an option (Admin only)
router.put('/options/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  const { name, imageUrl, price } = req.body;
  const updatedFields = { name, imageUrl, price };

  // Remove undefined fields so we only update what's provided
  Object.keys(updatedFields).forEach(key => updatedFields[key] === undefined && delete updatedFields[key]);

  try {
    const option = await Option.findByIdAndUpdate(req.params.id, updatedFields, { new: true });
    if (!option) return res.status(404).json({ message: 'Option not found' });
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json(option);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// DELETE an option (Admin only)
router.delete('/options/:id', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const option = await Option.findByIdAndDelete(req.params.id);
    if (!option) return res.status(404).json({ message: 'Option not found' });
    broadcastToAllUsers({ type: 'MENU_UPDATE' }); // Notify all users about menu update
    res.json({ message: 'Option deleted' });
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

module.exports = router;
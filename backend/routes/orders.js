const express = require('express');
const router = express.Router();
const { body, validationResult } = require('express-validator');
const Order = require('../models/Order');
const MenuItem = require('../models/MenuItem'); // Needed to populate order items
const authMiddleware = require('../middleware/authMiddleware');
const authorizeRoles = require('../middleware/authorizeRoles');
const { sendUpdateToUser, broadcastToAdmins } = require('../websocket');

// POST a new order
router.post(
  '/',
  [
    authMiddleware,
    [
      body('items', 'Items are required').isArray({ min: 1 }),
      body('items.*.itemId', 'Item ID is required').isMongoId(),
      body('items.*.quantity', 'Quantity is required').isInt({ min: 1 }),
      body('items.*.excludedIngredients').optional().isArray(),
      body('totalAmount', 'Total price is required').isNumeric(),
      body('customerName', 'Customer name is required').not().isEmpty(),
      body('orderType', 'Order type is required').isIn(['takeaway', 'eat_in', 'delivery']),
      body('arrivalTime').optional().isString(),
      // Conditional validation for delivery address
      body('address.street', 'Street is required for delivery').if(body('orderType').equals('delivery')).not().isEmpty(),
      body('address.city', 'City is required for delivery').if(body('orderType').equals('delivery')).not().isEmpty(),
      body('address.postalCode', 'Postal code is required for delivery').if(body('orderType').equals('delivery')).not().isEmpty(),
      body('address.phone', 'Phone number is required for delivery').if(body('orderType').equals('delivery')).not().isEmpty(),
    ],
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      console.error('Validation errors:', JSON.stringify(errors.array())); // Log validation errors
      return res.status(400).json({ errors: errors.array() });
    }

    const { items, totalAmount, customerName, orderType, arrivalTime, address } = req.body;

    try {
      const orderItems = await Promise.all(items.map(async (item) => {
        const menuItem = await MenuItem.findById(item.itemId);
        if (!menuItem) {
          throw new Error(`Menu item with id ${item.itemId} not found`);
        }
        return {
          itemId: menuItem._id,
          itemName: menuItem.name,
          itemDescription: menuItem.description,
          itemPrice: menuItem.price,
          itemImageUrl: menuItem.imageUrl,
          itemCategory: menuItem.category,
          itemOptions: item.itemOptions || [],
          excludedIngredients: item.excludedIngredients || [],
          quantity: item.quantity,
        };
      }));

      const orderData = {
        userId: req.userData.userId, // Link the order to the logged-in user
        customerName,
        orderType,
        arrivalTime,
        items: orderItems,
        totalAmount,
      };

      if (orderType === 'delivery') {
        orderData.address = address;
      }

      const order = new Order(orderData);

      const newOrder = await order.save();
      
      // Notify all connected admins about the new order
      broadcastToAdmins({
        type: 'NEW_ORDER',
        order: newOrder,
      });

      res.status(201).json(newOrder);
    } catch (err) {
      console.error(err.message);
      res.status(500).send('Server Error');
    }
  }
);

// GET the current user's orders
router.get('/my-orders', authMiddleware, async (req, res) => {
  try {
    const orders = await Order.find({ userId: req.userData.userId }).sort({ orderDate: -1 });
    res.json(orders);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// GET all orders (Admin only)
router.get('/', authMiddleware, authorizeRoles('admin'), async (req, res) => {
  try {
    const orders = await Order.find();
    res.json(orders);
  } catch (err) {
    console.error(err.message);
    res.status(500).send('Server Error');
  }
});

// PUT (update) order status (Admin only)
router.put(
  '/:id',
  [authMiddleware, authorizeRoles('admin'), [body('status', 'Status is required').not().isEmpty()]],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    try {
      const updatedOrder = await Order.findByIdAndUpdate(
        req.params.id,
        { status: req.body.status },
        { new: true }
      );
      if (!updatedOrder) return res.status(404).json({ message: 'Order not found' });

      // Send real-time update to the user
      if (updatedOrder.userId) {
        sendUpdateToUser(updatedOrder.userId.toString(), {
          type: 'ORDER_STATUS_UPDATE',
          order: updatedOrder,
        });
      }

      res.json(updatedOrder);
    } catch (err) {
      console.error(err.message);
      res.status(500).send('Server Error');
    }
  }
);

module.exports = router;

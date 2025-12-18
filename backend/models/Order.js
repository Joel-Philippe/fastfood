const mongoose = require('mongoose');

const orderItemSchema = new mongoose.Schema({
  itemId: { type: mongoose.Schema.Types.ObjectId, ref: 'MenuItem', required: true },
  itemName: { type: String, required: true },
  itemDescription: { type: String },
  itemPrice: { type: Number, required: true },
  itemImageUrl: { type: String },
  itemCategory: { type: String, required: true },
  itemOptions: [{ type: String }],
  excludedIngredients: [{ type: String }],
  quantity: { type: Number, required: true, min: 1 },
});

const orderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: false }, // Link to the user who placed the order
  customerName: { type: String, required: true },
  orderType: { type: String, required: true, enum: ['takeaway', 'eat_in', 'delivery'] },
  address: {
    street: { type: String },
    city: { type: String },
    postalCode: { type: String },
    phone: { type: String },
  },
  arrivalTime: { type: String }, // Optional
  items: [orderItemSchema], // Array of sub-documents
  totalAmount: { type: Number, required: true },
  orderDate: { type: Date, default: Date.now },
  status: { type: String, default: 'pending', enum: ['pending', 'preparing', 'ready', 'out_for_delivery', 'completed', 'cancelled'] },
});

module.exports = mongoose.model('Order', orderSchema);

const mongoose = require('mongoose');

const menuItemSchema = new mongoose.Schema({
  name: { type: String, required: true },
  description: { type: String, required: false }, // Made optional
  price: { type: Number, required: true },
  imageUrl: { type: String, required: false },
  category: {
    type: String,
    required: true,
  },
  // A flexible way to link to different option categories
  optionTypes: [{ type: String }],
  removableIngredients: [{ type: String }], // Re-add this field
});

module.exports = mongoose.model('MenuItem', menuItemSchema);

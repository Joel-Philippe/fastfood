const mongoose = require('mongoose');

const menuCategorySchema = new mongoose.Schema({
  name: { type: String, required: true },
  backgroundImageUrl: { type: String, required: false },
  fontColor: { type: String, required: false },
  backgroundColor: { type: String, required: false },
  type: { type: String, required: true, unique: true },
});

module.exports = mongoose.model('MenuCategory', menuCategorySchema);

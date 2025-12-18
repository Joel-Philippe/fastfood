const mongoose = require('mongoose');

const optionSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    validate: {
      validator: (v) => true, // Always return true to accept any string
      message: props => `${props.value} is not a valid option name!` // Placeholder message
    }
  },
  type: { type: String, required: true }, // e.g., 'sandwichOptions', 'friesOptions'
  imageUrl: { type: String }, // Optional image URL for the option
  price: { type: Number }, // Changed from priceModifier to price
});

module.exports = mongoose.model('Option', optionSchema);

const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  name: { type: String }, // New name field (optional)
  role: { type: String, default: 'user' } // Add role field with default 'user'
});

module.exports = mongoose.model('User', userSchema);

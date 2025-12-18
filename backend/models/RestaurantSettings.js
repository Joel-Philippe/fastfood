const mongoose = require('mongoose');

// Defines the structure for a single day's opening hours
const dailyHoursSchema = new mongoose.Schema({
  isOpen: { type: Boolean, default: true },
  openTime: { type: String, default: '11:00' }, // HH:mm format
  closeTime: { type: String, default: '22:00' }, // HH:mm format
}, { _id: false });

// Defines the main settings schema for the restaurant
const restaurantSettingsSchema = new mongoose.Schema({
  // Using a single, well-known ID to ensure there's only one settings document
  _id: { type: String, default: 'main_settings' },
  hours: {
    type: Map,
    of: dailyHoursSchema,
    default: {
      '1': { isOpen: true, openTime: '11:00', closeTime: '22:00' }, // Monday
      '2': { isOpen: true, openTime: '11:00', closeTime: '22:00' }, // Tuesday
      '3': { isOpen: true, openTime: '11:00', closeTime: '22:00' }, // Wednesday
      '4': { isOpen: true, openTime: '11:00', closeTime: '22:00' }, // Thursday
      '5': { isOpen: true, openTime: '11:00', closeTime: '23:00' }, // Friday
      '6': { isOpen: true, openTime: '11:00', closeTime: '23:00' }, // Saturday
      '7': { isOpen: false, openTime: '11:00', closeTime: '22:00' }, // Sunday
    }
  }
}, {
  // This ensures that if a document with _id 'main_settings' doesn't exist, it's created.
  // Otherwise, it prevents creating new documents.
  capped: { size: 1024, max: 1 }
});

module.exports = mongoose.model('RestaurantSettings', restaurantSettingsSchema);

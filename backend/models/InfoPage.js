const mongoose = require('mongoose');

const InfoPageSchema = new mongoose.Schema({
  title: { type: String, required: true },
  content: { type: String, required: true }, // Contenu en texte ou HTML/Markdown simple
  icon: { type: String, default: 'info' }, // Nom de l'icône Material
  order: { type: Number, default: 0 },
  isVisible: { type: Boolean, default: true }
}, { timestamps: true });

module.exports = mongoose.model('InfoPage', InfoPageSchema);

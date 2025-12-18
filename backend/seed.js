const mongoose = require('mongoose');
const dotenv = require('dotenv');
const bcrypt = require('bcryptjs'); // Import bcrypt
const User = require('./models/User'); // Import User model
const MenuCategory = require('./models/MenuCategory');
const MenuItem = require('./models/MenuItem');
const Option = require('./models/Option');

dotenv.config();

// --- Admin User Definition ---
const adminCredentials = {
  name: 'Admin',
  email: 'admin@example.com',
  password: 'password123', // Change this in a production environment
};


const options = [
    // Drink Options
    { name: 'Coca-Cola', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Coca-Cola Zero', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Fanta', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Sprite', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Orangina', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Ice Tea', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Eau Plate', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Perrier', type: 'drinkOptions', priceModifier: 0 },
    { name: 'Dr. Pepper', type: 'drinkOptions', priceModifier: 0 },
    { name: '7up', type: 'drinkOptions', priceModifier: 0 },
    // Sauce Options
    { name: 'Ketchup', type: 'sauceOptions', priceModifier: 0 },
    { name: 'Mayonnaise', type: 'sauceOptions', priceModifier: 0 },
    { name: 'Algérienne', type: 'sauceOptions', priceModifier: 0.5 },
    { name: 'Blanche', type: 'sauceOptions', priceModifier: 0.5 },
    { name: 'Samouraï', type: 'sauceOptions', priceModifier: 0.5 },
    { name: 'Harissa', type: 'sauceOptions', priceModifier: 0.5 },
    { name: 'BBQ', type: 'sauceOptions', priceModifier: 0.5 },
    { name: 'Poivre', type: 'sauceOptions', priceModifier: 0.5 },
    // Main Fillings for Tacos
    { name: 'Poulet', type: 'mainFillings', priceModifier: 0 },
    { name: 'Viande Hachée', type: 'mainFillings', priceModifier: 0 },
    { name: 'Merguez', type: 'mainFillings', priceModifier: 0 },
    { name: 'Cordon Bleu', type: 'mainFillings', priceModifier: 0 },
    { name: 'Kebab', type: 'mainFillings', priceModifier: 0 },
    // Removable Ingredients
    { name: 'Oignons', type: 'removableIngredients', priceModifier: 0 },
    { name: 'Salade', type: 'removableIngredients', priceModifier: 0 },
    { name: 'Tomates', type: 'removableIngredients', priceModifier: 0 },
    { name: 'Cornichons', type: 'removableIngredients', priceModifier: 0 },
];

const categories = [
  { name: 'Menus', type: 'menus', fontColor: '#FF5733' },
  { name: 'Tacos', type: 'tacos', fontColor: '#C70039' },
  { name: 'Pizzas', type: 'pizzas', fontColor: '#900C3F' },
  { name: 'Sandwichs', type: 'sandwichs', fontColor: '#581845' },
  { name: 'Burgers', type: 'burgers', fontColor: '#FFC300' },
  { name: 'Assiettes', type: 'assiettes', fontColor: '#DAF7A6' },
  { name: 'Accompagnements', type: 'sides', fontColor: '#33FF57' },
  { name: 'Desserts', type: 'desserts', fontColor: '#33D4FF' },
  { name: 'Boissons', type: 'boissons', fontColor: '#3357FF' },
];

const menuItems = [
  // Menus (10 items)
  { name: 'Menu Classic Burger', description: 'Le Classic Burger, frites, boisson 33cl.', price: 9.90, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Classic', drinkOptions: ['Coca-Cola', 'Orangina', 'Eau Plate'], sauceOptions: ['Ketchup', 'Mayonnaise'] },
  { name: 'Menu Tacos Poulet', description: 'Tacos Poulet, frites, boisson 33cl.', price: 10.50, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Tacos', drinkOptions: ['Coca-Cola', 'Fanta', 'Sprite'], sauceOptions: ['Algérienne', 'Blanche', 'Samouraï'] },
  { name: 'Menu Pizza Reine', description: 'Pizza Reine, boisson 33cl.', price: 11.00, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Pizza', drinkOptions: ['Coca-Cola', 'Ice Tea', 'Perrier'] },
  { name: 'Menu Double Bacon', description: 'Le Double Bacon Burger, frites, boisson 33cl.', price: 12.50, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Double+Bacon', drinkOptions: ['Coca-Cola Zero', 'Dr. Pepper', '7up'] },
  { name: 'Menu Enfant', description: 'Nuggets x4, frites, Capri-Sun, compote.', price: 6.50, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Enfant' },
  { name: 'Menu Végétarien', description: 'Burger Végétarien, frites, boisson 33cl.', price: 10.00, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Veggie', drinkOptions: ['Coca-Cola', 'Orangina', 'Eau Plate'] },
  { name: 'Menu Assiette Kebab', description: 'Assiette Kebab, boisson 33cl.', price: 12.00, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Assiette', drinkOptions: ['Coca-Cola', 'Fanta', 'Sprite'] },
  { name: 'Menu Sandwich Thon', description: 'Sandwich thon-mayonnaise, frites, boisson 33cl.', price: 8.50, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Sandwich', drinkOptions: ['Ice Tea', 'Orangina', 'Eau Plate'] },
  { name: 'Menu Duo', description: '2 pizzas au choix (hors spéciales), 2 boissons 33cl.', price: 20.00, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Duo' },
  { name: 'Menu Famille', description: '4 burgers au choix, 4 frites, 1 bouteille 1.5L.', price: 35.00, category: 'menus', imageUrl: 'https://via.placeholder.com/300x200.png/FF5733/FFFFFF?text=Menu+Famille' },

  // Tacos (10 items)
  { name: 'Tacos Poulet', description: 'Poulet mariné, sauce fromagère maison, frites.', price: 7.50, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Poulet', sauceOptions: ['Algérienne', 'Blanche', 'Samouraï', 'Harissa', 'Mayonnaise', 'Ketchup'], removableIngredients: ['Oignons', 'Salade', 'Tomates'] },
  { name: 'Tacos Viande Hachée', description: 'Viande hachée assaisonnée, sauce fromagère maison, frites.', price: 8.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+VH', sauceOptions: ['Algérienne', 'Blanche', 'Samouraï', 'BBQ'], removableIngredients: ['Oignons', 'Salade', 'Tomates'] },
  { name: 'Tacos Merguez', description: 'Merguez, sauce fromagère maison, frites.', price: 7.50, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Merguez', sauceOptions: ['Algérienne', 'Blanche', 'Harissa'], removableIngredients: ['Oignons', 'Salade', 'Tomates'] },
  { name: 'Tacos Cordon Bleu', description: 'Cordon bleu, sauce fromagère maison, frites.', price: 8.50, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Cordon+Bleu', sauceOptions: ['Blanche', 'Poivre', 'Mayonnaise'], removableIngredients: ['Salade', 'Tomates'] },
  { name: 'Tacos Kebab', description: 'Viande de kebab, sauce fromagère maison, frites.', price: 8.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Kebab', sauceOptions: ['Blanche', 'Samouraï', 'Harissa'], removableIngredients: ['Oignons', 'Salade', 'Tomates'] },
  { name: 'Tacos Mix (2 viandes)', description: 'Deux viandes au choix, sauce fromagère maison, frites.', price: 9.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Mix', mainFillings: ['Poulet', 'Viande Hachée', 'Merguez', 'Cordon Bleu', 'Kebab'], sauceOptions: ['Algérienne', 'Blanche', 'Samouraï', 'BBQ'] },
  { name: 'Tacos Végétarien', description: 'Galette de légumes, sauce fromagère maison, frites.', price: 7.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Veggie', sauceOptions: ['Blanche', 'Mayonnaise', 'Ketchup'], removableIngredients: ['Oignons'] },
  { name: 'Le Montagnard', description: 'Viande hachée, reblochon, lardons, sauce fromagère maison, frites.', price: 9.50, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Montagnard', sauceOptions: ['Blanche', 'Poivre'] },
  { name: 'Le Chèvre-Miel', description: 'Poulet, fromage de chèvre, miel, noix, sauce fromagère maison, frites.', price: 9.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Tacos+Chevre+Miel', sauceOptions: ['Blanche'] },
  { name: 'Le Giga Tacos', description: 'Trois viandes au choix, double frites, sauce fromagère maison.', price: 12.00, category: 'tacos', imageUrl: 'https://via.placeholder.com/300x200.png/C70039/FFFFFF?text=Giga+Tacos', mainFillings: ['Poulet', 'Viande Hachée', 'Merguez', 'Cordon Bleu', 'Kebab'], sauceOptions: ['Algérienne', 'Blanche', 'Samouraï', 'BBQ', 'Harissa'] },

  // Pizzas (10 items)
  { name: 'Margarita', description: 'Sauce tomate, mozzarella, basilic frais.', price: 8.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Margarita' },
  { name: 'Reine', description: 'Sauce tomate, mozzarella, jambon, champignons frais.', price: 9.50, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Reine' },
  { name: '4 Fromages', description: 'Crème fraîche, mozzarella, chèvre, emmental, bleu.', price: 11.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=4+Fromages' },
  { name: 'Orientale', description: 'Sauce tomate, mozzarella, merguez, poivrons, oignons.', price: 10.50, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Orientale' },
  { name: 'Calzone', description: 'Pizza pliée, sauce tomate, mozzarella, jambon, œuf.', price: 10.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Calzone' },
  { name: 'Végétarienne', description: 'Sauce tomate, mozzarella, poivrons, champignons, oignons, olives.', price: 9.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Vegetarienne' },
  { name: 'Saumon', description: 'Crème fraîche, mozzarella, saumon fumé, aneth.', price: 12.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Saumon' },
  { name: 'Kebab Pizza', description: 'Sauce tomate, mozzarella, viande de kebab, oignons, sauce blanche.', price: 11.50, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Kebab+Pizza' },
  { name: 'Hawaïenne', description: 'Sauce tomate, mozzarella, jambon, ananas.', price: 10.00, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Hawaienne' },
  { name: 'Chorizo', description: 'Sauce tomate, mozzarella, chorizo, poivrons.', price: 10.50, category: 'pizzas', imageUrl: 'https://via.placeholder.com/300x200.png/900C3F/FFFFFF?text=Chorizo' },

  // Sandwichs (10 items)
  { name: 'Le Parisien', description: 'Baguette tradition, jambon blanc supérieur, beurre, cornichons.', price: 5.00, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Le+Parisien' },
  { name: 'Poulet Crudités', description: 'Baguette, émincé de poulet, salade, tomate, mayonnaise.', price: 6.50, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Poulet+Crudites' },
  { name: 'Thon Mayonnaise', description: 'Baguette, thon, mayonnaise, salade, tomate.', price: 6.00, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Thon+Mayo' },
  { name: 'L\'Américain', description: 'Baguette, steak haché, frites, sauce au choix.', price: 7.00, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Americain', sauceOptions: ['Ketchup', 'Mayonnaise', 'Algérienne'] },
  { name: 'Le Végétarien', description: 'Baguette, galette de légumes, salade, tomate, sauce au choix.', price: 6.00, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Veggie+Sandwich', sauceOptions: ['Mayonnaise', 'Blanche'] },
  { name: 'Merguez Frites', description: 'Baguette, merguez, frites, sauce au choix.', price: 6.50, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Merguez+Frites', sauceOptions: ['Harissa', 'Algérienne'] },
  { name: 'Le Kebab', description: 'Pain kebab, viande de kebab, salade, tomate, oignons, sauce blanche.', price: 7.00, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Kebab' },
  { name: 'Le 3 Fromages', description: 'Baguette, chèvre, emmental, mozzarella, salade.', price: 6.50, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=3+Fromages' },
  { name: 'Le Nordique', description: 'Pain suédois, saumon fumé, crème fraîche, aneth, concombre.', price: 7.50, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Nordique' },
  { name: 'Le Panini', description: 'Pain panini, jambon, mozzarella, sauce tomate.', price: 5.50, category: 'sandwichs', imageUrl: 'https://via.placeholder.com/300x200.png/581845/FFFFFF?text=Panini' },

  // Burgers (10 items)
  { name: 'Le Classic Burger', description: 'Steak de boeuf 120g, cheddar, salade, tomate, oignons, sauce burger maison.', price: 7.00, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Classic+Burger', removableIngredients: ['Oignons', 'Cornichons'] },
  { name: 'Le Chicken Burger', description: 'Filet de poulet pané, salade, tomate, mayonnaise.', price: 6.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Chicken+Burger' },
  { name: 'Le Double Bacon', description: 'Deux steaks de boeuf 120g, double cheddar, bacon grillé, sauce BBQ.', price: 9.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Double+Bacon', removableIngredients: ['Oignons'] },
  { name: 'Le Fish Burger', description: 'Poisson pané, salade, sauce tartare.', price: 6.00, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Fish+Burger' },
  { name: 'Le Veggie Burger', description: 'Galette de légumes, salade, tomate, sauce au choix.', price: 6.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Veggie+Burger', sauceOptions: ['Mayonnaise', 'Ketchup'] },
  { name: 'Le Montagnard Burger', description: 'Steak de boeuf 120g, reblochon, lardons, oignons caramélisés.', price: 9.00, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Montagnard' },
  { name: 'Le Chèvre-Miel Burger', description: 'Steak de boeuf 120g, fromage de chèvre, miel, noix.', price: 8.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Chevre+Miel' },
  { name: 'Le Pepper Burger', description: 'Steak de boeuf 120g, cheddar, sauce au poivre.', price: 7.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Pepper+Burger' },
  { name: 'Le Triple Cheese', description: 'Trois steaks 45g, triple cheddar, oignons, ketchup, moutarde.', price: 5.50, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Triple+Cheese' },
  { name: 'Le Giga Burger', description: 'Trois steaks 120g, cheddar, bacon, salade, tomate, oignons, sauce maison.', price: 13.00, category: 'burgers', imageUrl: 'https://via.placeholder.com/300x200.png/FFC300/000000?text=Giga+Burger' },

  // Assiettes (10 items)
  { name: 'Assiette Kebab', description: 'Lamelles de kebab, salade composée, frites et pain.', price: 10.50, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Kebab', sauceOptions: ['Blanche', 'Harissa', 'Samouraï'] },
  { name: 'Assiette Poulet', description: 'Filet de poulet grillé, salade composée, frites et pain.', price: 11.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Poulet', sauceOptions: ['Blanche', 'Moutarde', 'BBQ'] },
  { name: 'Assiette Merguez', description: 'Merguez grillées, salade composée, frites et pain.', price: 10.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Merguez', sauceOptions: ['Harissa', 'Algérienne'] },
  { name: 'Assiette Steak', description: 'Steak de boeuf, salade composée, frites et pain.', price: 12.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Steak', sauceOptions: ['Poivre', 'BBQ'] },
  { name: 'Assiette Brochettes', description: 'Brochettes de poulet marinées, salade composée, frites et pain.', price: 11.50, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Brochettes' },
  { name: 'Assiette Mixte', description: 'Kebab, poulet, merguez, salade composée, frites et pain.', price: 13.50, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Mixte' },
  { name: 'Assiette Végétarienne', description: 'Falafels, houmous, salade composée, frites et pain.', price: 10.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Veggie' },
  { name: 'Assiette Saumon', description: 'Pavé de saumon grillé, riz, légumes de saison.', price: 14.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Saumon' },
  { name: 'Assiette Cordon Bleu', description: 'Cordon bleu, salade composée, frites et pain.', price: 11.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Cordon+Bleu' },
  { name: 'Assiette Escalope Milanaise', description: 'Escalope de veau panée, pâtes, sauce tomate.', price: 13.00, category: 'assiettes', imageUrl: 'https://via.placeholder.com/300x200.png/DAF7A6/000000?text=Assiette+Milanaise' },

  // Accompagnements (10 items)
  { name: 'Frites', description: 'Portion de frites croustillantes.', price: 2.50, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Frites' },
  { name: 'Potatoes', description: 'Portion de potatoes épicées.', price: 3.00, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Potatoes' },
  { name: 'Salade Verte', description: 'Salade fraîche de saison.', price: 3.50, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Salade' },
  { name: 'Onion Rings', description: 'Rondelles d\'oignon frites.', price: 3.50, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Onion+Rings' },
  { name: 'Mozzarella Sticks', description: 'Bâtonnets de mozzarella panés.', price: 4.00, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Mozza+Sticks' },
  { name: 'Nuggets', description: 'Bouchées de poulet panées.', price: 4.50, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Nuggets' },
  { name: 'Coleslaw', description: 'Salade de chou et carottes.', price: 2.00, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Coleslaw' },
  { name: 'Riz', description: 'Portion de riz blanc.', price: 2.00, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Riz' },
  { name: 'Légumes Grillés', description: 'Mélange de légumes de saison grillés.', price: 4.00, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Legumes' },
  { name: 'Pain à l\'ail', description: 'Baguette grillée à l\'ail et au persil.', price: 2.50, category: 'sides', imageUrl: 'https://via.placeholder.com/300x200.png/33FF57/000000?text=Pain+Ail' },

  // Desserts (10 items)
  { name: 'Tiramisu', description: 'Dessert italien classique au café.', price: 3.50, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Tiramisu' },
  { name: 'Mousse au Chocolat', description: 'Mousse au chocolat maison.', price: 3.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Mousse' },
  { name: 'Tarte au Daim', description: 'Tarte croquante au chocolat et caramel.', price: 3.50, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Tarte+Daim' },
  { name: 'Crêpe au Nutella', description: 'Crêpe chaude garnie de Nutella.', price: 3.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Crepe' },
  { name: 'Gaufre au Sucre', description: 'Gaufre de Bruxelles saupoudrée de sucre glace.', price: 2.50, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Gaufre' },
  { name: 'Salade de Fruits', description: 'Mélange de fruits frais de saison.', price: 3.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Salade+Fruits' },
  { name: 'Glace (2 boules)', description: 'Deux boules de glace au choix.', price: 3.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Glace' },
  { name: 'Fondant au Chocolat', description: 'Fondant au chocolat au coeur coulant.', price: 4.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Fondant' },
  { name: 'Panna Cotta', description: 'Panna cotta et son coulis de fruits rouges.', price: 3.50, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Panna+Cotta' },
  { name: 'Donut', description: 'Donut glacé au choix.', price: 2.00, category: 'desserts', imageUrl: 'https://via.placeholder.com/300x200.png/33D4FF/000000?text=Donut' },

  // Boissons (10 items)
  { name: 'Coca-Cola', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Coca-Cola' },
  { name: 'Orangina', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Orangina' },
  { name: 'Fanta', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Fanta' },
  { name: 'Sprite', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Sprite' },
  { name: 'Eau Plate', description: '50cl', price: 1.00, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Eau' },
  { name: 'Perrier', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Perrier' },
  { name: 'Ice Tea Pêche', description: '33cl', price: 1.50, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Ice+Tea' },
  { name: 'Jus d\'Orange', description: '25cl', price: 2.00, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Jus+Orange' },
  { name: 'Red Bull', description: '250ml', price: 3.00, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Red+Bull' },
  { name: 'Café', description: 'Expresso', price: 1.20, category: 'boissons', imageUrl: 'https://via.placeholder.com/300x200.png/3357FF/FFFFFF?text=Cafe' },
];


const seedDB = async () => {
  try {
    await mongoose.connect(process.env.MONGODB_URI);

    console.log('Deleting existing data...');
    await User.deleteMany({}); // Clear existing users
    await MenuCategory.deleteMany({});
    await MenuItem.deleteMany({});
    await Option.deleteMany({});

    console.log('--- Creating Admin User ---');
    console.log(`Email: ${adminCredentials.email}`);
    console.log(`Password: ${adminCredentials.password}`);
    
    const adminExists = await User.findOne({ email: adminCredentials.email });
    if (!adminExists) {
      const hashedPassword = await bcrypt.hash(adminCredentials.password, 12);
      const adminUser = new User({
        name: adminCredentials.name,
        email: adminCredentials.email,
        password: hashedPassword,
        role: 'admin',
      });
      await adminUser.save();
      console.log('Admin user created successfully!');
    } else {
      console.log('Admin user already exists.');
    }
    // --- End of Admin User Creation ---

    console.log('Inserting new data...');
    await MenuCategory.insertMany(categories);
    await MenuItem.insertMany(menuItems);
    await Option.insertMany(options);

    console.log('Database seeded successfully!');
  } catch (error) {
    console.error('Error seeding database:', error);
  } finally {
    mongoose.connection.close();
  }
};

seedDB();
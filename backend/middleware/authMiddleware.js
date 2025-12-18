const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
  try {
    const token = req.headers.authorization.split(' ')[1]; // Expects 'Bearer TOKEN'
    if (!token) {
      return res.status(401).json({ message: 'Authentication failed: No token provided.' });
    }
    const decodedToken = jwt.verify(token, process.env.JWT_SECRET); // Use the same secret as in auth.js
    req.userData = { userId: decodedToken.userId, role: decodedToken.role }; // Attach user data to request
    next();
  } catch (error) {
    return res.status(401).json({ message: 'Authentication failed: Invalid token.' });
  }
};

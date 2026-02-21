const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const userController = require('../controllers/userController');

// Protected routes
router.delete('/account', authenticate, userController.deleteAccount);

module.exports = router;
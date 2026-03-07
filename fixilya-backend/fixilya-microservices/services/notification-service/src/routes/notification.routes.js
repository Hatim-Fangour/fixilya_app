const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const controller = require('../controllers/notification.controller');

// All routes require a valid Firebase ID token
router.use(authenticate);

// Register FCM device token (called on login / token refresh)
router.post('/register-token', controller.registerToken);

// Unregister FCM device token (called on logout)
router.delete('/remove-token', controller.removeToken);

// List notifications for the authenticated user
router.get('/', controller.getNotifications);

// Get unread notification count
router.get('/unread-count', controller.getUnreadCount);

// Mark all notifications as read (must be before /:id/read to avoid conflict)
router.put('/read-all', controller.markAllAsRead);

// Mark a single notification as read
router.put('/:id/read', controller.markAsRead);

module.exports = router;

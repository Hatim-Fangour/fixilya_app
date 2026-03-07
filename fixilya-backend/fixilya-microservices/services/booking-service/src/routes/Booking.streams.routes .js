const express = require('express');
const router  = express.Router();

const stream           = require('../controllers/booking.streams.controller');
const { authenticate } = require('../../../../shared/middleware/auth');

// All SSE routes require authentication
router.use(authenticate);

// ─────────────────────────────────────────────
// IMPORTANT: specific routes MUST come before /:id
// to avoid Express matching "requests" as an id param
// ─────────────────────────────────────────────

// Provider streams
router.get('/requests',  stream.streamRequests);
router.get('/active',    stream.streamActive);
router.get('/declined',  stream.streamDeclined);
router.get('/activity',  stream.streamActivity);

// Client streams
router.get('/client',    stream.streamClientBookings);

// Notification streams
router.get('/notifications', stream.streamNotifications);
router.get('/unread-count',  stream.streamUnreadCount);

// Single booking — keep last (has :id param)
router.get('/booking/:id',   stream.streamSingleBooking);

module.exports = router;
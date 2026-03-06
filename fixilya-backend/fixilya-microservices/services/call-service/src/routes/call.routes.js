'use strict';

const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const rateLimit = require('express-rate-limit');
const callController = require('../controllers/call.controller');

// Strict rate limit for call initiation: 10 calls per minute per IP
const callInitiateLimit = rateLimit({
  windowMs: 60 * 1000,
  max: 10,
  message: { success: false, message: 'Too many call requests, please wait' },
  standardHeaders: true,
  legacyHeaders: false,
});

// POST /api/calls/initiate
router.post('/initiate', callInitiateLimit, authenticate, callController.initiateCall);

// GET /api/calls/:callId/accept
router.get('/:callId/accept', authenticate, callController.acceptCall);

module.exports = router;

const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/payment.controller');
const { body } = require('express-validator');
const { validate } = require('../middleware/validate');

// Validation
const createPaymentValidation = [
  body('bookingId').notEmpty().withMessage('Booking ID required'),
  body('amount').isFloat({ min: 1 }).withMessage('Valid amount required'),
];

const confirmPaymentValidation = [
  body('paymentIntentId').notEmpty().withMessage('Payment intent ID required'),
];

// Webhook (no auth required)
router.post('/webhook', paymentController.handleWebhook);

// Authenticated routes
router.post('/create-intent', paymentController.authenticate, createPaymentValidation, validate, paymentController.createPaymentIntent);
router.post('/confirm', paymentController.authenticate, confirmPaymentValidation, validate, paymentController.confirmPayment);
router.get('/history', paymentController.authenticate, paymentController.getPaymentHistory);

module.exports = router;
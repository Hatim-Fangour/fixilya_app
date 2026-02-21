const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/auth');
const paymentController = require('../controllers/paymentController');
const { body } = require('express-validator');
const { validate } = require('../middleware/validate');

// Validation
const createPaymentValidation = [
  body('bookingId').notEmpty().withMessage('Booking ID is required'),
  body('amount').isFloat({ min: 1 }).withMessage('Valid amount is required'),
];

const confirmPaymentValidation = [
  body('paymentIntentId').notEmpty().withMessage('Payment intent ID is required'),
];

// Routes
router.post('/create-intent', authenticate, createPaymentValidation, validate, paymentController.createPaymentIntent);
router.post('/confirm', authenticate, confirmPaymentValidation, validate, paymentController.confirmPayment);
router.get('/history', authenticate, paymentController.getPaymentHistory);

module.exports = router;
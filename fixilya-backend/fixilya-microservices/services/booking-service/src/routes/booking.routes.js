const express = require('express');
const router = express.Router();
const { authenticate } = require('../../../../../middleware/auth');
const bookingController = require('../controllers/bookingController');
const { body } = require('express-validator');
const { validate } = require('../../../../shared/middleware/validate');

// Validation rules
const createBookingValidation = [
  body('handymanId').notEmpty().withMessage('Handyman ID is required'),
  body('serviceType').notEmpty().withMessage('Service type is required'),
  body('scheduledDate').isISO8601().withMessage('Valid date is required'),
  body('address').notEmpty().withMessage('Address is required'),
];

const updateStatusValidation = [
  body('status').isIn(['pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'])
    .withMessage('Invalid status'),
];

// Routes
router.post('/', authenticate, createBookingValidation, validate, bookingController.createBooking);
router.get('/', authenticate, bookingController.getMyBookings);
router.get('/:id', authenticate, bookingController.getBooking);
router.patch('/:id/status', authenticate, updateStatusValidation, validate, bookingController.updateBookingStatus);
router.delete('/:id', authenticate, bookingController.cancelBooking);

module.exports = router;
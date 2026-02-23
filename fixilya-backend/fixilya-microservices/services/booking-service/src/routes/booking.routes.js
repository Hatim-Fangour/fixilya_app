const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/booking.controller');
const { body } = require('express-validator');
const { validate } = require('../middleware/validate');

// Validation
const createBookingValidation = [
  body('handymanId').notEmpty().withMessage('Handyman ID required'),
  body('serviceType').notEmpty().withMessage('Service type required'),
  body('scheduledDate').isISO8601().withMessage('Valid date required'),
  body('address').notEmpty().withMessage('Address required'),
];

const updateStatusValidation = [
  body('status').isIn(['pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'rejected'])
    .withMessage('Invalid status'),
];

// Apply authentication to all routes
router.use(bookingController.authenticate);

// Routes
router.post('/', createBookingValidation, validate, bookingController.createBooking);
router.get('/', bookingController.getMyBookings);
router.get('/:id', bookingController.getBooking);
router.patch('/:id/status', updateStatusValidation, validate, bookingController.updateBookingStatus);
router.delete('/:id', bookingController.cancelBooking);

module.exports = router;
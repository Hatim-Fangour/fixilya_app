const express = require('express');
const { body, param, query } = require('express-validator');
const router = express.Router();

const ctrl             = require('../controllers/booking.controller');
const { authenticate } = require('../../../../shared/middleware/auth');
const { validate }     = require('../../../../shared/middleware/validate');

// ─────────────────────────────────────────────
// SSE stream sub-router — mount BEFORE /:id routes
// ─────────────────────────────────────────────
const streamRoutes = require('./../routes/Booking.streams.routes ');
router.use('/stream', streamRoutes);

// All booking REST routes require a valid Firebase JWT
router.use(authenticate);

// ─────────────────────────────────────────────
// CREATE
// ─────────────────────────────────────────────

router.post(
  '/',
  [
    body().custom((_, { req }) => {
      if (!req.body.providerId && !req.body.handymanId) throw new Error('providerId or handymanId is required');
      return true;
    }),
    body('service')       .notEmpty().isString()  .withMessage('service is required'),
    body('description')   .notEmpty().isString()  .withMessage('description is required'),
    body().custom((_, { req }) => {
      if (!req.body.scheduledAt && !req.body.scheduledDate) throw new Error('scheduledAt or scheduledDate is required');
      return true;
    }),
    body('address')       .notEmpty().isString()  .withMessage('address is required'),
    body('city')          .notEmpty().isString()  .withMessage('city is required'),
    body('clientName')    .notEmpty().isString()  .withMessage('clientName is required'),
    body('clientPhone')   .notEmpty().isString()  .withMessage('clientPhone is required'),
    body('estimatedPrice').optional().isFloat({ min: 0 }),
    validate,
  ],
  ctrl.createBooking
);

// ─────────────────────────────────────────────
// READ
// ─────────────────────────────────────────────

router.get(
  '/',
  [
    query('status').optional().isString(),
    query('page')  .optional().isInt({ min: 1 }).toInt(),
    query('limit') .optional().isInt({ min: 1, max: 100 }).toInt(),
    validate,
  ],
  ctrl.listBookings
);

router.get(
  '/:id',
  [param('id').notEmpty().withMessage('Booking id is required'), validate],
  ctrl.getBooking
);

// ─────────────────────────────────────────────
// STATUS TRANSITIONS
// ─────────────────────────────────────────────

router.put('/:id/accept',   [param('id').notEmpty(), validate], ctrl.acceptBooking);
router.put('/:id/decline',  [param('id').notEmpty(), body('reason').optional().isString().trim(), validate], ctrl.declineBooking);
router.put('/:id/start',    [param('id').notEmpty(), validate], ctrl.startBooking);
router.put('/:id/complete', [param('id').notEmpty(), validate], ctrl.completeBooking);
router.put('/:id/cancel',   [param('id').notEmpty(), body('reason').optional().isString().trim(), validate], ctrl.cancelBooking);

// ─────────────────────────────────────────────
// REVIEWS
// ─────────────────────────────────────────────

router.post(
  '/:id/review',
  [
    param('id')    .notEmpty(),
    body('rating') .isInt({ min: 1, max: 5 }).withMessage('rating must be 1–5'),
    body('comment').optional().isString().trim(),
    validate,
  ],
  ctrl.submitReview
);

module.exports = router;
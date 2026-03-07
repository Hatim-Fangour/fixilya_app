const bookingService = require('../services/booking.service');
const audit          = require('../../../../shared/utils/auditLogger');

const SVC = 'booking-service';

// ─────────────────────────────────────────────
// CREATE
// ─────────────────────────────────────────────

/** POST /api/bookings */
exports.createBooking = async (req, res, next) => {
  const { handymanId, providerId, handymanName, service, scheduledDate, scheduledAt, address, city } = req.body;
  try {
    const result = await bookingService.createBooking(req.user.uid, req.body);
    audit.log(SVC, 'BOOKING_CREATE', {
      actor:     audit.actor(req),
      bookingId: result.bookingId,
      handymanId: handymanId || providerId,
      handymanName,
      service,
      scheduledFor: scheduledDate || scheduledAt,
      address,
      city,
    });
    res.status(201).json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_CREATE', err, {
      actor:      audit.actor(req),
      handymanId: handymanId || providerId,
      service,
    });
    next(err);
  }
};

// ─────────────────────────────────────────────
// READ
// ─────────────────────────────────────────────

/** GET /api/bookings/:id */
exports.getBooking = async (req, res, next) => {
  try {
    const booking = await bookingService.getBookingById(
      req.params.id,
      req.user.uid,
      req.user.role
    );
    res.json({ success: true, data: booking });
  } catch (err) { next(err); }
};

/** GET /api/bookings  —  query: ?status=&page=&limit= */
exports.listBookings = async (req, res, next) => {
  try {
    const { status, page, limit } = req.query;
    const result = await bookingService.getUserBookings(
      req.user.uid,
      req.user.role,
      {
        status,
        page:  page  ? parseInt(page,  10) : 1,
        limit: limit ? parseInt(limit, 10) : 20,
      }
    );
    res.json({ success: true, ...result });
  } catch (err) { next(err); }
};

// ─────────────────────────────────────────────
// STATUS TRANSITIONS
// ─────────────────────────────────────────────

/** PUT /api/bookings/:id/accept  — provider only */
exports.acceptBooking = async (req, res, next) => {
  try {
    const result = await bookingService.acceptBooking(
      req.params.id, req.user.uid, req.user.role
    );
    audit.log(SVC, 'BOOKING_ACCEPT', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_ACCEPT', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

/** PUT /api/bookings/:id/decline  — provider only  |  body: { reason? } */
exports.declineBooking = async (req, res, next) => {
  try {
    const result = await bookingService.declineBooking(
      req.params.id, req.user.uid, req.user.role, req.body.reason
    );
    audit.log(SVC, 'BOOKING_DECLINE', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
      reason:    req.body.reason ?? null,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_DECLINE', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

/** PUT /api/bookings/:id/start  — provider only */
exports.startBooking = async (req, res, next) => {
  try {
    const result = await bookingService.startBooking(
      req.params.id, req.user.uid, req.user.role
    );
    audit.log(SVC, 'BOOKING_START', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_START', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

/** PUT /api/bookings/:id/complete  — provider only */
exports.completeBooking = async (req, res, next) => {
  try {
    const result = await bookingService.completeBooking(
      req.params.id, req.user.uid, req.user.role
    );
    audit.log(SVC, 'BOOKING_COMPLETE', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_COMPLETE', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

/** PUT /api/bookings/:id/cancel  — client or provider  |  body: { reason? } */
exports.cancelBooking = async (req, res, next) => {
  try {
    const result = await bookingService.cancelBooking(
      req.params.id, req.user.uid, req.user.role, req.body.reason
    );
    audit.log(SVC, 'BOOKING_CANCEL', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
      reason:    req.body.reason ?? null,
    });
    res.json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'BOOKING_CANCEL', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

// ─────────────────────────────────────────────
// REVIEWS
// ─────────────────────────────────────────────

/** POST /api/bookings/:id/review  — client only  |  body: { rating, comment? } */
exports.submitReview = async (req, res, next) => {
  try {
    const result = await bookingService.submitReview(
      req.params.id, req.user.uid, req.body
    );
    audit.log(SVC, 'REVIEW_SUBMIT', {
      actor:     audit.actor(req),
      bookingId: req.params.id,
      rating:    req.body.rating,
    });
    res.status(201).json({ success: true, data: result });
  } catch (err) {
    audit.error(SVC, 'REVIEW_SUBMIT', err, {
      actor:     audit.actor(req),
      bookingId: req.params.id,
    });
    next(err);
  }
};

const admin = require('../../../../shared/config/firebase');
const { publishEvent } = require('../../../../shared/config/redis');
const { AppError } = require('../../../../shared/utils/appError');
const logger = require('../../../../shared/utils/logger');

const db = admin.firestore();

// ─────────────────────────────────────────────
// Firestore collection names
// ─────────────────────────────────────────────
const COL = {
  BOOKINGS:      'bookings',
  HANDYMEN:      'handymen',
  ACTIVITY:      'activity',
  NOTIFICATIONS: 'notifications',
};

// ─────────────────────────────────────────────
// Redis — event channels
// Consumed by: notification-service, payment-service
// ─────────────────────────────────────────────
const EVENTS = {
  BOOKING_CREATED:   'booking:created',
  BOOKING_CONFIRMED: 'booking:confirmed',
  BOOKING_DECLINED:  'booking:declined',
  BOOKING_STARTED:   'booking:started',
  BOOKING_COMPLETED: 'booking:completed',
  BOOKING_CANCELLED: 'booking:cancelled',
};

// ─────────────────────────────────────────────
// Redis — cache TTLs (seconds)
// ─────────────────────────────────────────────
const TTL = {
  BOOKING: 300,  // 5 min  — single booking doc
  LIST:    60,   // 1 min  — user booking list (invalidated on every mutation)
};

// ─────────────────────────────────────────────
// State machine
// ─────────────────────────────────────────────
const STATUS_TRANSITIONS = {
  pending:     ['confirmed', 'declined', 'cancelled'],
  confirmed:   ['in_progress', 'cancelled'],
  in_progress: ['completed', 'disputed'],
  completed:   [],
  declined:    [],
  cancelled:   [],
  disputed:    ['resolved', 'cancelled'],
  resolved:    [],
};

// Which actor may trigger each target status
const TRANSITION_ACTOR = {
  confirmed:   'provider',
  declined:    'provider',
  in_progress: 'provider',
  completed:   'client',
  cancelled:   'any',
  disputed:    'client',
  resolved:    'admin',
};

class BookingService {
  // ─────────────────────────────────────────────
  // Redis client (lazy — resolved on first use)
  // Uses the same Redis instance as publishEvent
  // but via a direct ioredis / redis client for GET/SET.
  //
  // We create it lazily from the shared redis module
  // so the service starts even when Redis is briefly
  // unavailable (cache miss → fall through to Firestore).
  // ─────────────────────────────────────────────
  _getRedis() {
    if (this._redis) return this._redis;
    try {
      // shared/config/redis may export the client directly
      // or as getRedisClient(). Support both patterns.
      const redisModule = require('../../../../shared/config/redis');
      this._redis = redisModule.redisClient
        ?? redisModule.getRedisClient?.()
        ?? redisModule.client
        ?? null;
    } catch {
      this._redis = null;
    }
    return this._redis;
  }

  // ─────────────────────────────────────────────
  // CREATE
  // ─────────────────────────────────────────────

  /**
   * Create a new booking request (client).
   * Writes to Firestore, publishes Redis booking:created event.
   */
  async createBooking(clientUid, data) {
    try {
      const {
        providerId: _pid,
        handymanId: _hid,
        providerName: _pname,
        handymanName: _hname,
        clientName,
        clientPhone,
        categoryId,
        service,
        description,
        scheduledAt: _schedAt,
        scheduledDate: _schedDate,
        address,
        city,
        estimatedPrice,
      } = data;

      // Support both field name conventions (frontend sends handymanId/handymanName/scheduledDate)
      const providerId   = _pid || _hid;
      const providerName = _pname || _hname;
      const scheduledAt  = _schedAt || _schedDate;

      logger.info(`📝 Creating booking — client: ${clientUid}, provider: ${providerId}`);

      // Verify provider exists and is approved
      const providerSnap = await db.collection(COL.HANDYMEN).doc(providerId).get();
      if (!providerSnap.exists) {
        throw new AppError('Provider not found', 404);
      }

      const provider = providerSnap.data();
      if (!provider.approved || provider.suspended) {
        throw new AppError('Provider is not currently available', 400);
      }

      const bookingRef = await db.collection(COL.BOOKINGS).add({
        clientUid,
        clientId:       clientUid,
        clientName,
        clientPhone,
        providerId,
        handymanId:     providerId,
        providerName:   providerName || provider.fullName || 'Provider',
        handymanName:   providerName || provider.fullName || 'Provider',
        categoryId:     categoryId ?? null,
        service,
        description,
        scheduledAt:    admin.firestore.Timestamp.fromDate(new Date(scheduledAt)),
        address,
        city,
        location:       `${address}, ${city}`,
        estimatedPrice: estimatedPrice ?? null,
        hasReview:      false,
        status:         'pending',
        createdAt:      admin.firestore.FieldValue.serverTimestamp(),
        updatedAt:      admin.firestore.FieldValue.serverTimestamp(),
      });

      const bookingId = bookingRef.id;
      logger.info(`✅ Booking created: ${bookingId}`);

      // In-app notification for the handyman
      await this._createNotification({
        userId: providerId,
        type: 'new_request',
        title: 'New Booking Request',
        message: `${clientName || 'A client'} requested ${service}`,
        bookingId,
      });

      // Publish event (Redis — non-fatal if unavailable)
      await this._publish(EVENTS.BOOKING_CREATED, {
        bookingId,
        clientUid,
        clientName,
        providerId,
        providerName: provider.fullName,
        service,
        scheduledAt,
      });

      // Invalidate list caches for both parties
      await this._invalidateListCache(providerId);
      await this._invalidateListCache(clientUid);

      return { bookingId, message: 'Booking created successfully' };
    } catch (error) {
      logger.error(`❌ createBooking: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // READ  (Redis cache → Firestore fallback)
  // ─────────────────────────────────────────────

  /**
   * Get a single booking by ID.
   * Cached in Redis for TTL.BOOKING seconds.
   * Access: booking participants or admin only.
   */
  async getBookingById(bookingId, uid, role) {
    try {
      const cacheKey = `booking:${bookingId}`;
      const cached   = await this._cacheGet(cacheKey);

      if (cached) {
        this._assertAccess(cached, uid, role);
        return cached;
      }

      const doc = await db.collection(COL.BOOKINGS).doc(bookingId).get();
      if (!doc.exists) throw new AppError('Booking not found', 404);

      const booking = { id: doc.id, ...doc.data() };
      this._assertAccess(booking, uid, role);

      await this._cacheSet(cacheKey, booking, TTL.BOOKING);
      return booking;
    } catch (error) {
      logger.error(`❌ getBookingById: ${error.message}`);
      throw error;
    }
  }

  /**
   * Paginated booking list for the authenticated user.
   * Cached in Redis for TTL.LIST seconds.
   *
   * @param {string} uid
   * @param {'client'|'provider'|'admin'} role
   * @param {{ status?, page?, limit? }} opts
   */
  async getUserBookings(uid, role, { status, page = 1, limit = 20 } = {}) {
    try {
      const cacheKey = `bookings:${uid}:${role}:${status ?? 'all'}:p${page}:l${limit}`;
      const cached   = await this._cacheGet(cacheKey);
      if (cached) return cached;

      const field = role === 'client' ? 'clientUid' : 'providerId';

      let query = db
        .collection(COL.BOOKINGS)
        .where(field, '==', uid)
        .orderBy('createdAt', 'desc');

      if (status) query = query.where('status', '==', status);

      const snap    = await query.get();
      const allDocs = snap.docs.map(d => ({ id: d.id, ...d.data() }));
      const total   = allDocs.length;
      const start   = (page - 1) * limit;

      const result = {
        bookings: allDocs.slice(start, start + limit),
        total,
        page,
        limit,
        pages: Math.ceil(total / limit),
      };

      await this._cacheSet(cacheKey, result, TTL.LIST);
      return result;
    } catch (error) {
      logger.error(`❌ getUserBookings: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // STATUS TRANSITIONS — single source of truth
  // ─────────────────────────────────────────────

  /**
   * Update booking status with full validation.
   *
   * Checks:
   *   1. Booking exists
   *   2. Actor is a participant or admin
   *   3. Actor has permission for the target status (TRANSITION_ACTOR)
   *   4. Transition is valid per state machine (STATUS_TRANSITIONS)
   *
   * Then:
   *   - Writes to Firestore (+ updates handyman stats on complete)
   *   - Creates activity record
   *   - Publishes Redis event
   *   - Invalidates cache
   */
  async updateStatus(bookingId, uid, role, newStatus, { reason } = {}) {
    try {
      const booking = await this._getBookingRaw(bookingId);

      // ── 1. Ownership ─────────────────────────
      const isClient   = booking.clientUid === uid || booking.clientId === uid;
      const isProvider = booking.providerId === uid || booking.handymanId === uid;

      if (role !== 'admin' && !isClient && !isProvider) {
        throw new AppError('Access denied', 403);
      }

      // ── 2. Actor rule ─────────────────────────
      const requiredActor = TRANSITION_ACTOR[newStatus];
      if (requiredActor && role !== 'admin') {
        if (requiredActor === 'provider' && !isProvider) {
          throw new AppError(`Only the provider can set status to '${newStatus}'`, 403);
        }
        if (requiredActor === 'client' && !isClient) {
          throw new AppError(`Only the client can set status to '${newStatus}'`, 403);
        }
      }

      // ── 3. State machine ──────────────────────
      const allowed = STATUS_TRANSITIONS[booking.status] ?? [];
      if (!allowed.includes(newStatus)) {
        throw new AppError(
          `Cannot transition from '${booking.status}' to '${newStatus}'`,
          400
        );
      }

      // ── 4. Firestore write ────────────────────
      const timestamps = {
        confirmed:   { acceptedAt:  admin.firestore.FieldValue.serverTimestamp() },
        declined:    { declinedAt:  admin.firestore.FieldValue.serverTimestamp() },
        in_progress: { startedAt:   admin.firestore.FieldValue.serverTimestamp() },
        completed:   { completedAt: admin.firestore.FieldValue.serverTimestamp() },
        cancelled:   { cancelledAt: admin.firestore.FieldValue.serverTimestamp() },
      };

      await db.collection(COL.BOOKINGS).doc(bookingId).update({
        status: newStatus,
        // Use specific field name per transition so the UI can display the right label
        ...(reason && newStatus === 'declined'  ? { declineReason:       reason } : {}),
        ...(reason && newStatus === 'cancelled' ? { cancellationReason:  reason } : {}),
        ...(timestamps[newStatus] ?? {}),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ── 5. Handyman stats on completion ───────
      if (newStatus === 'completed') {
        const amount = parseFloat(booking.estimatedPrice ?? booking.amount ?? 0);
        await db.collection(COL.HANDYMEN).doc(booking.providerId).update({
          completedJobs: admin.firestore.FieldValue.increment(1),
          totalEarnings: admin.firestore.FieldValue.increment(amount),
          updatedAt:     admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      // ── 6. Activity record ────────────────────
      await this._createActivity(booking, uid, newStatus, reason);

      // ── 6b. In-app notification ─────────────
      const notifMap = {
        confirmed: {
          userId: booking.clientUid || booking.clientId,
          type: 'booking_accepted',
          title: 'Booking Confirmed!',
          message: `${booking.providerName || 'Your handyman'} accepted your booking for ${booking.service}`,
        },
        declined: {
          userId: booking.clientUid || booking.clientId,
          type: 'booking_declined',
          title: 'Booking Declined',
          message: `${booking.providerName || 'The handyman'} declined your booking for ${booking.service}${reason ? ': ' + reason : ''}`,
        },
        in_progress: {
          userId: booking.clientUid || booking.clientId,
          type: 'job_started',
          title: 'Job Started',
          message: `${booking.providerName || 'Your handyman'} has started working on ${booking.service}`,
        },
        completed: {
          userId: booking.clientUid || booking.clientId,
          type: 'job_completed',
          title: 'Job Completed',
          message: `${booking.providerName || 'Your handyman'} has completed ${booking.service}`,
        },
        cancelled: {
          userId: isClient
            ? (booking.providerId || booking.handymanId)
            : (booking.clientUid || booking.clientId),
          type: 'booking_cancelled',
          title: 'Booking Cancelled',
          message: isClient
            ? `${booking.clientName || 'The client'} cancelled the booking for ${booking.service}${reason ? ': ' + reason : ''}`
            : `${booking.providerName || 'The handyman'} cancelled the booking for ${booking.service}${reason ? ': ' + reason : ''}`,
        },
      };

      const notif = notifMap[newStatus];
      if (notif) {
        await this._createNotification({ ...notif, bookingId });
      }

      // ── 7. Redis event ────────────────────────
      const eventMap = {
        confirmed:   EVENTS.BOOKING_CONFIRMED,
        declined:    EVENTS.BOOKING_DECLINED,
        in_progress: EVENTS.BOOKING_STARTED,
        completed:   EVENTS.BOOKING_COMPLETED,
        cancelled:   EVENTS.BOOKING_CANCELLED,
      };

      if (eventMap[newStatus]) {
        await this._publish(eventMap[newStatus], {
          bookingId,
          clientUid:    booking.clientUid,
          clientName:   booking.clientName,
          providerId:   booking.providerId,
          providerName: booking.providerName,
          service:      booking.service,
          newStatus,
          reason:       reason ?? null,
          actorUid:     uid,
          actorRole:    role,
        });
      }

      // ── 8. Cache invalidation ─────────────────
      await this._invalidateBookingCache(bookingId);
      await this._invalidateListCache(booking.clientUid);
      await this._invalidateListCache(booking.providerId);

      logger.info(`✅ Booking ${bookingId}: ${booking.status} → ${newStatus} (by ${uid})`);
      return { success: true, bookingId, status: newStatus };
    } catch (error) {
      logger.error(`❌ updateStatus: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // NAMED TRANSITION HELPERS (thin wrappers)
  // ─────────────────────────────────────────────

  acceptBooking(bookingId, uid, role) {
    return this.updateStatus(bookingId, uid, role, 'confirmed');
  }

  declineBooking(bookingId, uid, role, reason) {
    return this.updateStatus(bookingId, uid, role, 'declined', { reason });
  }

  startBooking(bookingId, uid, role) {
    return this.updateStatus(bookingId, uid, role, 'in_progress');
  }

  completeBooking(bookingId, uid, role) {
    return this.updateStatus(bookingId, uid, role, 'completed');
  }

  cancelBooking(bookingId, uid, role, reason) {
    return this.updateStatus(bookingId, uid, role, 'cancelled', { reason });
  }

  // ─────────────────────────────────────────────
  // REVIEWS
  // ─────────────────────────────────────────────

  /**
   * Submit a rating + comment for a completed booking (client only).
   * Duplicate guard via `hasReview` flag on the booking doc.
   */
  async submitReview(bookingId, clientUid, { rating, comment }) {
    try {
      const booking = await this._getBookingRaw(bookingId);

      if (booking.clientUid !== clientUid)   throw new AppError('Access denied', 403);
      if (booking.status    !== 'completed') throw new AppError('Can only review completed bookings', 400);
      if (booking.hasReview)                 throw new AppError('Review already submitted', 409);

      const batch = db.batch();

      // Write review to sub-collection
      const reviewRef = db
        .collection(COL.BOOKINGS)
        .doc(bookingId)
        .collection('reviews')
        .doc();

      batch.set(reviewRef, {
        reviewerUid: clientUid,
        revieweeUid: booking.providerId,
        rating,
        comment:   comment ?? null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mark booking as reviewed
      batch.update(db.collection(COL.BOOKINGS).doc(bookingId), {
        hasReview: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Accumulate rating on provider doc (avg = ratingTotal / reviewCount)
      batch.update(db.collection(COL.HANDYMEN).doc(booking.providerId), {
        reviewCount: admin.firestore.FieldValue.increment(1),
        ratingTotal: admin.firestore.FieldValue.increment(rating),
        updatedAt:   admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();

      await this._invalidateBookingCache(bookingId);

      logger.info(`⭐ Review submitted — booking: ${bookingId}, rating: ${rating}`);
      return { success: true, message: 'Review submitted' };
    } catch (error) {
      logger.error(`❌ submitReview: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE — Firestore helpers
  // ─────────────────────────────────────────────

  async _getBookingRaw(bookingId) {
    const doc = await db.collection(COL.BOOKINGS).doc(bookingId).get();
    if (!doc.exists) throw new AppError('Booking not found', 404);
    return { id: doc.id, ...doc.data() };
  }

  _assertAccess(booking, uid, role) {
    if (role === 'admin') return;
    const isClient   = booking.clientUid === uid || booking.clientId === uid;
    const isProvider = booking.providerId === uid || booking.handymanId === uid;
    if (!isClient && !isProvider) {
      throw new AppError('Access denied', 403);
    }
  }

  async _createActivity(booking, actorUid, newStatus, reason) {
    const descriptions = {
      confirmed:   `You accepted a booking from ${booking.clientName}`,
      declined:    `You declined a booking from ${booking.clientName}`,
      in_progress: `You started the ${booking.service} job`,
      completed:   `Completed ${booking.service} for ${booking.clientName}`,
      cancelled:   `Booking cancelled${reason ? `: ${reason}` : ''}`,
    };

    try {
      await db.collection(COL.ACTIVITY).add({
        userId:      actorUid,
        type:        `booking_${newStatus}`,
        title:       `Booking ${newStatus.replace('_', ' ')}`,
        description: descriptions[newStatus] ?? `Status changed to ${newStatus}`,
        bookingId:   booking.id,
        createdAt:   admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (e) {
      logger.warn(`⚠️ Activity record failed (non-fatal): ${e.message}`);
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE — In-app notification (Firestore)
  // ─────────────────────────────────────────────

  async _createNotification({ userId, type, title, message, bookingId }) {
    try {
      await db.collection(COL.NOTIFICATIONS).add({
        userId,
        type,
        title,
        message,
        bookingId: bookingId ?? null,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info(`🔔 Notification → ${userId} (${type})`);
    } catch (e) {
      logger.warn(`⚠️ Notification write failed (non-fatal): ${e.message}`);
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE — Redis helpers
  //
  // All cache operations are non-fatal: if Redis is
  // down the service falls through to Firestore.
  // ─────────────────────────────────────────────

  async _publish(channel, payload) {
    try {
      await publishEvent(channel, payload);
      logger.info(`📡 Published: ${channel}`);
    } catch (e) {
      logger.warn(`⚠️ Redis publish failed (${channel}): ${e.message}`);
    }
  }

  async _cacheGet(key) {
    try {
      const redis = this._getRedis();
      if (!redis) return null;

      const raw = await redis.get(key);
      return raw ? JSON.parse(raw) : null;
    } catch (e) {
      logger.warn(`⚠️ Cache GET failed (${key}): ${e.message}`);
      return null;
    }
  }

  async _cacheSet(key, value, ttlSeconds) {
    try {
      const redis = this._getRedis();
      if (!redis) return;

      // Support both redis@4 (setEx) and ioredis (set with EX option)
      if (typeof redis.setEx === 'function') {
        await redis.setEx(key, ttlSeconds, JSON.stringify(value));
      } else {
        await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
      }
    } catch (e) {
      logger.warn(`⚠️ Cache SET failed (${key}): ${e.message}`);
    }
  }

  async _invalidateBookingCache(bookingId) {
    try {
      const redis = this._getRedis();
      if (!redis) return;
      await redis.del(`booking:${bookingId}`);
    } catch (e) {
      logger.warn(`⚠️ Cache DEL failed: ${e.message}`);
    }
  }

  async _invalidateListCache(uid) {
    try {
      const redis = this._getRedis();
      if (!redis) return;

      // Scan and delete all list cache keys for this user
      // Pattern: bookings:<uid>:*
      let cursor = 0;
      do {
        // Support both redis@4 (scan returns { cursor, keys })
        // and ioredis (scan returns [cursor, keys])
        const result = await redis.scan(cursor, { MATCH: `bookings:${uid}:*`, COUNT: 100 });
        const keys   = Array.isArray(result) ? result[1] : result.keys;
        cursor       = Array.isArray(result) ? parseInt(result[0]) : result.cursor;

        if (keys?.length > 0) await redis.del(keys);
      } while (cursor !== 0);
    } catch (e) {
      logger.warn(`⚠️ List cache invalidation failed: ${e.message}`);
    }
  }
}

module.exports = new BookingService();
const admin = require('../../../../shared/config/firebase');
const logger = require('../../../../shared/utils/logger');

const db = admin.firestore();

// ─────────────────────────────────────────────
// SSE helpers
// ─────────────────────────────────────────────

/**
 * Initialise an SSE response.
 * Sets the required headers and disables buffering.
 */
function initSSE(res) {
  res.setHeader('Content-Type',  'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection',    'keep-alive');
  res.setHeader('X-Accel-Buffering', 'no'); // nginx: disable proxy buffering
  res.flushHeaders();
}

/**
 * Write a named SSE event.
 * @param {import('express').Response} res
 * @param {string}  event  — event type name (e.g. 'update')
 * @param {unknown} data   — will be JSON-serialised
 */
function sendEvent(res, event, data) {
  res.write(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

/**
 * Start a 25-second heartbeat so proxies / load-balancers do not
 * close idle SSE connections.
 * @returns {NodeJS.Timer} interval handle — clear it on close
 */
function startHeartbeat(res) {
  return setInterval(() => {
    res.write(': ping\n\n');
  }, 25_000);
}

/**
 * Serialise a Firestore DocumentSnapshot to a plain object.
 * Converts Firestore Timestamps → ISO-8601 strings so Flutter
 * can parse them with DateTime.parse().
 */
function serializeDoc(doc) {
  const data = { id: doc.id, ...doc.data() };
  for (const [key, val] of Object.entries(data)) {
    if (val && typeof val.toDate === 'function') {
      data[key] = val.toDate().toISOString();
    }
  }
  return data;
}

// ─────────────────────────────────────────────
// PROVIDER STREAMS
// ─────────────────────────────────────────────

/**
 * GET /api/bookings/stream/requests
 * Pending booking requests for the authenticated provider.
 */
exports.streamRequests = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/requests — provider: ${uid}`);

  const unsub = db.collection('bookings')
    .where('providerId', '==', uid)
    .where('status', '==', 'pending')
    .orderBy('createdAt', 'desc')
    .onSnapshot(
      (snap) => {
        const docs = snap.docs.map(serializeDoc);
        sendEvent(res, 'update', docs);
      },
      (err) => {
        logger.error(`❌ streamRequests error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
    logger.info(`🔌 SSE /stream/requests closed — provider: ${uid}`);
  });
};

/**
 * GET /api/bookings/stream/active
 * Confirmed + in-progress bookings for the authenticated provider.
 */
exports.streamActive = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/active — provider: ${uid}`);

  const unsub = db.collection('bookings')
    .where('providerId', '==', uid)
    .where('status', 'in', ['confirmed', 'in_progress'])
    .orderBy('createdAt', 'desc')
    .onSnapshot(
      (snap) => {
        const docs = snap.docs.map(serializeDoc);
        sendEvent(res, 'update', docs);
      },
      (err) => {
        logger.error(`❌ streamActive error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
    logger.info(`🔌 SSE /stream/active closed — provider: ${uid}`);
  });
};

/**
 * GET /api/bookings/stream/declined
 * Last 20 declined bookings for the authenticated provider.
 */
exports.streamDeclined = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/declined — provider: ${uid}`);

  const unsub = db.collection('bookings')
    .where('providerId', '==', uid)
    .where('status', '==', 'declined')
    .orderBy('createdAt', 'desc')
    .limit(20)
    .onSnapshot(
      (snap) => {
        sendEvent(res, 'update', snap.docs.map(serializeDoc));
      },
      (err) => {
        logger.error(`❌ streamDeclined error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
  });
};

/**
 * GET /api/bookings/stream/activity
 * Last 20 activity records for the authenticated user.
 */
exports.streamActivity = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/activity — uid: ${uid}`);

  const unsub = db.collection('activity')
    .where('userId', '==', uid)
    .orderBy('createdAt', 'desc')
    .limit(20)
    .onSnapshot(
      (snap) => {
        sendEvent(res, 'update', snap.docs.map(serializeDoc));
      },
      (err) => {
        logger.error(`❌ streamActivity error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
  });
};

// ─────────────────────────────────────────────
// CLIENT STREAMS
// ─────────────────────────────────────────────

/**
 * GET /api/bookings/stream/client?status=pending
 * All bookings for the authenticated client, optionally filtered by status.
 */
exports.streamClientBookings = (req, res) => {
  const uid    = req.user.uid;
  const status = req.query.status; // optional
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/client — client: ${uid}, status: ${status ?? 'all'}`);

  let query = db.collection('bookings')
    .where('clientUid', '==', uid)
    .orderBy('createdAt', 'desc');

  if (status && status !== 'all') {
    query = query.where('status', '==', status);
  }

  const unsub = query.onSnapshot(
    (snap) => {
      sendEvent(res, 'update', snap.docs.map(serializeDoc));
    },
    (err) => {
      logger.error(`❌ streamClientBookings error: ${err.message}`);
      res.end();
    }
  );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
    logger.info(`🔌 SSE /stream/client closed — client: ${uid}`);
  });
};

// ─────────────────────────────────────────────
// NOTIFICATION STREAMS
// ─────────────────────────────────────────────

/**
 * GET /api/bookings/stream/notifications
 * Last 50 notifications for the authenticated user.
 */
exports.streamNotifications = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/notifications — uid: ${uid}`);

  const unsub = db.collection('notifications')
    .where('userId', '==', uid)
    .orderBy('createdAt', 'desc')
    .limit(50)
    .onSnapshot(
      (snap) => {
        sendEvent(res, 'update', snap.docs.map(serializeDoc));
      },
      (err) => {
        logger.error(`❌ streamNotifications error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
  });
};

/**
 * GET /api/bookings/stream/unread-count
 * Live unread notification count for the authenticated user.
 * Emits: { count: number }
 */
exports.streamUnreadCount = (req, res) => {
  const uid = req.user.uid;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/unread-count — uid: ${uid}`);

  const unsub = db.collection('notifications')
    .where('userId', '==', uid)
    .where('read', '==', false)
    .onSnapshot(
      (snap) => {
        logger.info(`🔔 Unread count for ${uid}: ${snap.size}`);
        sendEvent(res, 'update', { count: snap.size });
      },
      (err) => {
        logger.error(`❌ streamUnreadCount error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
    logger.info(`🔌 SSE /stream/unread-count closed — uid: ${uid}`);
  });
};

/**
 * GET /api/bookings/stream/booking/:id
 * Live snapshot of a single booking document.
 */
exports.streamSingleBooking = (req, res) => {
  const uid       = req.user.uid;
  const bookingId = req.params.id;
  initSSE(res);
  const heartbeat = startHeartbeat(res);

  logger.info(`📡 SSE /stream/booking/${bookingId} — uid: ${uid}`);

  const unsub = db.collection('bookings')
    .doc(bookingId)
    .onSnapshot(
      (doc) => {
        if (!doc.exists) {
          sendEvent(res, 'update', null);
          return;
        }

        const data = serializeDoc(doc);

        // Access guard — only booking participants can stream it
        if (data.clientUid !== uid && data.providerId !== uid) {
          res.end();
          return;
        }

        sendEvent(res, 'update', data);
      },
      (err) => {
        logger.error(`❌ streamSingleBooking error: ${err.message}`);
        res.end();
      }
    );

  req.on('close', () => {
    unsub();
    clearInterval(heartbeat);
  });
};
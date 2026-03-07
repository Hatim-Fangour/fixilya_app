/**
 * auditLogger.js — Structured audit trail for all business operations.
 *
 * Writes to  <service-cwd>/logs/audit.log
 * Format: one JSON object per line (NDJSON), human-readable with full context.
 *
 * Usage:
 *   const audit = require('../../../../shared/utils/auditLogger');
 *   audit.log('booking-service', 'BOOKING_CREATE', { userId, role, ip, bookingId, ... });
 *   audit.error('booking-service', 'BOOKING_ACCEPT', error, { userId, bookingId });
 */

const winston = require('winston');
const path    = require('path');
const fs      = require('fs');

// Ensure logs/ directory exists relative to the calling service's cwd
const logsDir = path.join(process.cwd(), 'logs');
if (!fs.existsSync(logsDir)) fs.mkdirSync(logsDir, { recursive: true });

// ─────────────────────────────────────────────
// Winston instance — audit channel only
// ─────────────────────────────────────────────
const _winstonAudit = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss.SSS' }),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({
      filename: path.join(logsDir, 'audit.log'),
      maxsize: 10 * 1024 * 1024,   // rotate at 10 MB
      maxFiles: 5,                   // keep 5 rotated files
      tailable: true,
    }),
  ],
});

// ─────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────

/**
 * Log a successful (or in-progress) operation.
 *
 * @param {string} service   e.g. 'booking-service'
 * @param {string} operation e.g. 'BOOKING_CREATE'
 * @param {object} details   { userId, role, ip, bookingId, ... }
 */
function log(service, operation, details = {}) {
  _winstonAudit.info({
    service,
    operation,
    result: 'success',
    ...details,
  });
}

/**
 * Log a failed operation.
 *
 * @param {string} service
 * @param {string} operation
 * @param {Error}  err
 * @param {object} details
 */
function error(service, operation, err, details = {}) {
  _winstonAudit.info({
    service,
    operation,
    result: 'error',
    error: {
      message: err?.message ?? String(err),
      code:    err?.statusCode ?? err?.code ?? 500,
    },
    ...details,
  });
}

/**
 * Extract a clean actor object from an Express request.
 * Safe to call even when req.user is not set (e.g. public routes).
 */
function actor(req) {
  return {
    uid:   req?.user?.uid   ?? 'anonymous',
    role:  req?.user?.role  ?? 'unknown',
    email: req?.user?.email ?? undefined,
    ip:    req?.ip ?? req?.connection?.remoteAddress ?? 'unknown',
  };
}

module.exports = { log, error, actor };

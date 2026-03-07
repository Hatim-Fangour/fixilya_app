/**
 * requestLogger.js — Express middleware that logs every incoming HTTP request
 * and its response (status + latency) to the audit log.
 *
 * Mount early in app.js:
 *   const requestLogger = require('../../../../shared/middleware/requestLogger');
 *   app.use(requestLogger('booking-service'));
 */

const audit = require('../utils/auditLogger');

/**
 * @param {string} serviceName  Human-readable service label
 */
module.exports = function requestLogger(serviceName) {
  return function (req, res, next) {
    const startedAt = Date.now();

    // Log when request arrives
    const entry = {
      method:  req.method,
      path:    req.path,
      query:   Object.keys(req.query).length  ? req.query  : undefined,
      body:    _sanitizeBody(req.body),
      actor:   audit.actor(req),
    };

    // Capture response finish
    res.on('finish', () => {
      const latencyMs = Date.now() - startedAt;
      const success   = res.statusCode < 400;

      if (success) {
        audit.log(serviceName, 'HTTP_REQUEST', {
          ...entry,
          statusCode: res.statusCode,
          latencyMs,
        });
      } else {
        audit.error(
          serviceName,
          'HTTP_REQUEST',
          { message: `HTTP ${res.statusCode}`, statusCode: res.statusCode },
          { ...entry, statusCode: res.statusCode, latencyMs }
        );
      }
    });

    next();
  };
};

// Remove sensitive fields from logged body
function _sanitizeBody(body) {
  if (!body || typeof body !== 'object') return undefined;
  const safe = { ...body };
  for (const key of ['password', 'currentPassword', 'newPassword', 'token', 'refreshToken', 'secret']) {
    if (key in safe) safe[key] = '[REDACTED]';
  }
  return Object.keys(safe).length ? safe : undefined;
}

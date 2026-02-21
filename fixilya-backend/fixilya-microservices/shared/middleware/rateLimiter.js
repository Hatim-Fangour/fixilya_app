const rateLimit = require('express-rate-limit');

const createRateLimiter = (windowMs, max, message) => {
  return rateLimit({
    windowMs: windowMs || 60000, // 1 minute default
    max: max || 100, // 100 requests per minute default
    message: message || 'Too many requests, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
  });
};

// Different limiters for different endpoints
const generalLimiter = createRateLimiter(60000, 100);
const authLimiter = createRateLimiter(900000, 5, 'Too many login attempts'); // 5 per 15 min
const uploadLimiter = createRateLimiter(60000, 10, 'Too many uploads'); // 10 per min

module.exports = {
  generalLimiter,
  authLimiter,
  uploadLimiter,
};
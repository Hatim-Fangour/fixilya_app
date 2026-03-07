// ─────────────────────────────────────────────
// Load .env FIRST — before any other require.
//
// .env lives at:  booking-service/.env
// app.js lives at: booking-service/src/app.js
// → path goes up 2 levels: src/ → booking-service/
// ─────────────────────────────────────────────
const path = require('path');
const fs   = require('fs');

const ENV_PATH = path.resolve(__dirname, '..', '.env');

if (!fs.existsSync(ENV_PATH)) {
  console.error(`\n❌  .env file not found at: ${ENV_PATH}`);
  console.error('    Run:  copy .env.example .env   then fill in your Firebase credentials.\n');
  process.exit(1);
}

require('dotenv').config({ path: ENV_PATH });

const express   = require('express');
const cors      = require('cors');
const helmet    = require('helmet');
const rateLimit = require('express-rate-limit');
const logger         = require('./../../../shared/utils/logger');
const requestLogger  = require('../../../shared/middleware/requestLogger');
const bookingRoutes  = require('./routes/booking.routes');

const app = express();

// ─────────────────────────────────────────────
// Security & parsing
// ─────────────────────────────────────────────

app.use(helmet());

const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));

app.use(express.json({ limit: '10kb' }));
app.use(requestLogger('booking-service'));

// ─────────────────────────────────────────────
// Rate limiting
// ─────────────────────────────────────────────

const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 150,
  message: { success: false, message: 'Too many requests. Please try again later.' },
  standardHeaders: true,
  legacyHeaders:   false,
});

app.use('/api/bookings', generalLimiter);

// ─────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────

app.use('/api/bookings', bookingRoutes);

// ─────────────────────────────────────────────
// Health check
// ─────────────────────────────────────────────

app.get('/health', (_req, res) => {
  res.json({
    status:    'healthy',
    service:   'booking-service',
    timestamp: new Date().toISOString(),
  });
});

// ─────────────────────────────────────────────
// 404
// ─────────────────────────────────────────────

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Route not found: ${req.method} ${req.originalUrl}`,
  });
});

// ─────────────────────────────────────────────
// Global error handler
// ─────────────────────────────────────────────

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  const statusCode    = err.statusCode || 500;
  const isOperational = err.isOperational ?? false;

  if (statusCode === 500 && !isOperational) {
    logger.error(`💥 Unexpected error on ${req.method} ${req.originalUrl}`);
    logger.error(err.stack);
  } else {
    logger.warn(`⚠️  ${statusCode} ${err.message} — ${req.method} ${req.originalUrl}`);
  }

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ─────────────────────────────────────────────
// Startup
// ─────────────────────────────────────────────

const PORT   = process.env.PORT || 3003;
const server = app.listen(PORT, () => {
  logger.info(`📅 Booking Service running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});

// ─────────────────────────────────────────────
// Graceful shutdown
// ─────────────────────────────────────────────

const shutdown = (signal) => {
  logger.info(`🛑 ${signal} received — shutting down Booking Service gracefully...`);
  server.close(() => {
    logger.info('✅ HTTP server closed. Process exiting.');
    process.exit(0);
  });
  setTimeout(() => {
    logger.error('❌ Graceful shutdown timed out — forcing exit.');
    process.exit(1);
  }, 10_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT',  () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  logger.error('🔥 Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  logger.error('💥 Uncaught Exception:', error);
  shutdown('uncaughtException');
});

module.exports = app;
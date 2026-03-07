require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const logger        = require('../../../shared/utils/logger');
const requestLogger = require('../../../shared/middleware/requestLogger');
const userRoutes    = require('./routes/user.routes');

const app = express();

// ─────────────────────────────────────────────
// Security & parsing middleware
// ─────────────────────────────────────────────

app.use(helmet());

const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));

app.use(express.json({ limit: '10kb' })); // Guard against oversized payloads
app.use(requestLogger('user-service'));

// ─────────────────────────────────────────────
// Rate limiting
// ─────────────────────────────────────────────

// Strict limiter for public endpoints (no auth token needed)
// complete-profile-skip and complete-profile are hit once per registration
const registrationLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// General limiter for all other API routes
const generalLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  message: {
    success: false,
    message: 'Too many requests from this IP, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

app.use('/api/users/complete-profile-skip', registrationLimiter);
app.use('/api/users/complete-profile', registrationLimiter);
app.use('/api/users', generalLimiter);

// ─────────────────────────────────────────────
// Routes
// ─────────────────────────────────────────────

// All user + handyman routes (handyman is mounted inside user.routes.js)
app.use('/api/users', userRoutes);

// ─────────────────────────────────────────────
// Health check
// ─────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'user-service',
    timestamp: new Date().toISOString(),
  });
});

// ─────────────────────────────────────────────
// 404 — unmatched routes
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
  const statusCode = err.statusCode || 500;
  const isOperational = err.isOperational ?? false; // AppError sets this to true

  if (statusCode === 500 && !isOperational) {
    // Unexpected error — log full stack
    logger.error(`💥 Unexpected error on ${req.method} ${req.originalUrl}`);
    logger.error(err.stack);
  } else {
    // Known operational error (validation, not found, etc.) — log lightly
    logger.warn(`⚠️  ${statusCode} ${err.message} — ${req.method} ${req.originalUrl}`);
  }

  res.status(statusCode).json({
    success: false,
    message: err.message || 'Internal server error',
    ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
  });
});

// ─────────────────────────────────────────────
// Server startup
// ─────────────────────────────────────────────

const PORT = process.env.PORT || 3002;

const server = app.listen(PORT, () => {
  logger.info(`👤 User Service running on port ${PORT} [${process.env.NODE_ENV || 'development'}]`);
});

// ─────────────────────────────────────────────
// Graceful shutdown
// Ensures in-flight requests finish before the process exits.
// Critical when deploying with Docker / PM2 / cloud run.
// ─────────────────────────────────────────────

const shutdown = (signal) => {
  logger.info(`🛑 ${signal} received — shutting down User Service gracefully...`);

  server.close(() => {
    logger.info('✅ HTTP server closed. Process exiting.');
    process.exit(0);
  });

  // Force-kill if graceful shutdown takes too long (e.g. hung DB connection)
  setTimeout(() => {
    logger.error('❌ Graceful shutdown timed out — forcing exit.');
    process.exit(1);
  }, 10_000);
};

process.on('SIGTERM', () => shutdown('SIGTERM')); // Docker / K8s stop
process.on('SIGINT', () => shutdown('SIGINT'));   // Ctrl+C in terminal

// Catch unhandled promise rejections so the process doesn't silently die
process.on('unhandledRejection', (reason) => {
  logger.error('🔥 Unhandled Promise Rejection:', reason);
});

process.on('uncaughtException', (error) => {
  logger.error('💥 Uncaught Exception:', error);
  shutdown('uncaughtException');
});

module.exports = app;
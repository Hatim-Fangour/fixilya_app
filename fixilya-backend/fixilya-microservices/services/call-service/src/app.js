'use strict';

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });

const path = require('path');
const validateEnv = require(path.join(__dirname, '../../../shared/config/validateEnv'));
validateEnv(['FIREBASE_PROJECT_ID', 'AGORA_APP_ID', 'AGORA_APP_CERTIFICATE']);

const express = require('express');
const helmet  = require('helmet');
const cors    = require('cors');
const morgan  = require('morgan');

const logger        = require(path.join(__dirname, '../../../shared/utils/logger'));
const requestLogger = require(path.join(__dirname, '../../../shared/middleware/requestLogger'));
const { AppError }  = require(path.join(__dirname, '../../../shared/utils/appError'));
const corsOptions   = require(path.join(__dirname, '../../../shared/config/cors'));

const app  = express();
const PORT = process.env.PORT || 3007;

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(helmet());
app.use(cors(corsOptions()));
app.use(express.json());
app.use(requestLogger('call-service'));
app.use(morgan('combined', {
  stream: { write: (msg) => logger.info(msg.trim()) },
}));

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({
    service:   'call-service',
    status:    'healthy',
    port:      PORT,
    timestamp: new Date().toISOString(),
  });
});

// ── Routes ────────────────────────────────────────────────────────────────────
const callRoutes = require('./routes/call.routes');
app.use('/api/calls', callRoutes);

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, req, res, next) => {
  logger.error('call-service error:', err);

  if (err instanceof AppError && err.isOperational) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
    });
  }

  res.status(500).json({ success: false, message: 'Internal server error' });
});

app.listen(PORT, () => {
  logger.info(`📞 Call Service running on port ${PORT}`);
  console.log(`📞 Call Service running on port ${PORT}`);
});

module.exports = app;

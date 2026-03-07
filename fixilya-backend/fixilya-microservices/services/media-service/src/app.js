require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

const logger        = require('./utils/logger');
const requestLogger = require('../../../shared/middleware/requestLogger');

const app = express();
const PORT = process.env.PORT || 3006;

// ── Middleware ────────────────────────────────────────────────────────────────

app.use(helmet());
const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));
app.use(express.json({ limit: '15mb' }));        // allow base64-encoded images
app.use(express.urlencoded({ extended: true, limit: '15mb' }));
app.use(requestLogger('media-service'));
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) },
}));

// ── Health check ─────────────────────────────────────────────────────────────

app.get('/health', (req, res) => {
  res.json({
    service: 'media-service',
    status: 'healthy',
    port: PORT,
    timestamp: new Date().toISOString(),
  });
});

// ── Routes ───────────────────────────────────────────────────────────────────

const mediaRoutes = require('./routes/media.routes');
app.use('/api/media', mediaRoutes);

// ── Error handler ─────────────────────────────────────────────────────────────

app.use((err, req, res, next) => {
  logger.error('[Media] unhandled error:', err);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

// ── Start ─────────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  logger.info(`🖼️  Media Service running on port ${PORT}`);
  console.log(`🖼️  Media Service running on port ${PORT}`);
});

module.exports = app;

require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const validateEnv = require('../../../shared/config/validateEnv');
validateEnv(['FIREBASE_PROJECT_ID']);

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

// Import shared utilities
const logger        = require(path.join(__dirname, '../../../shared/utils/logger'));
const requestLogger = require(path.join(__dirname, '../../../shared/middleware/requestLogger'));
const { AppError } = require(path.join(__dirname, '../../../shared/utils/appError'));

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));
app.use(express.json());
app.use(requestLogger('auth-service'));
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) },
}));

// Health check
app.get('/health', (req, res) => {
  res.json({
    service: 'auth-service',
    status: 'healthy',
    port: PORT,
    timestamp: new Date().toISOString(),
  });
});

// Import routes
const authRoutes = require('./routes/auth.routes');
app.use('/api/auth', authRoutes);

// Agora RTC token generation
const agoraRoutes = require('./routes/agora.routes');
app.use('/api/agora', agoraRoutes);

// FCM device token registration / removal
const notificationTokenRoutes = require('./routes/notification-token.routes');
app.use('/api/notifications', notificationTokenRoutes);

// ✅ FIXED: Error handler that respects AppError statusCode
app.use((err, req, res, next) => {
  // Log the error
  logger.error('Error:', err);
  
  // ✅ Check if it's an AppError (operational error)
  if (err.isOperational && err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      message: err.message,
      statusCode: err.statusCode,
    });
  }

  // ✅ Handle other errors (programming errors)
  console.error('Unexpected error:', err);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    statusCode: 500,
  });
});

app.listen(PORT, () => {
  logger.info(`🔐 Auth Service running on port ${PORT}`);
  console.log(`🔐 Auth Service running on port ${PORT}`);
});

module.exports = app;
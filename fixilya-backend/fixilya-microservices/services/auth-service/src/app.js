require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

// Import shared utilities
const logger = require(path.join(__dirname, '../../../shared/utils/logger'));
const { AppError } = require(path.join(__dirname, '../../../shared/utils/appError')); // ✅ Import AppError

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json());
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
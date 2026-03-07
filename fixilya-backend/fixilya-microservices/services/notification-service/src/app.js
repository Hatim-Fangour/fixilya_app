require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const requestLogger = require('../../../shared/middleware/requestLogger');
const notificationRoutes = require('./routes/notification.routes');

const app = express();
const PORT = process.env.PORT || 3005;

// Middleware
app.use(helmet());
const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));
app.use(express.json());
app.use(requestLogger('notification-service'));
app.use(morgan('combined'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    service: 'notification-service',
    status: 'healthy',
    port: PORT,
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/api/notifications', notificationRoutes);

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

app.listen(PORT, () => {
  console.log(`🔔 Notification Service running on port ${PORT}`);
});

module.exports = app;
require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');

const logger = require(path.join(__dirname, '../../../shared/utils/logger'));

const app = express();
const PORT = process.env.PORT || 3003;

app.use(helmet());
app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(morgan('combined', {
  stream: { write: (message) => logger.info(message.trim()) },
}));

app.get('/health', (req, res) => {
  res.json({
    service: 'booking-service',
    status: 'healthy',
    port: PORT,
  });
});

// Use your existing booking routes
const bookingRoutes = require('../../../routes/bookingRoutes'); // Your existing file
app.use('/api/bookings', bookingRoutes);

app.use((err, req, res, next) => {
  logger.error('Error:', err);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

app.listen(PORT, () => {
  logger.info(`📅 Booking Service running on port ${PORT}`);
  console.log(`📅 Booking Service running on port ${PORT}`);
});

module.exports = app;
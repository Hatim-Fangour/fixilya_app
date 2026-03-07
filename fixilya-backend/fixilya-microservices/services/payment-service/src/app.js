require('dotenv').config();
if (!process.env.STRIPE_SECRET_KEY) {
  console.warn('⚠️  STRIPE_SECRET_KEY not set — payment endpoints will not work until configured.');
}

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const morgan = require('morgan');
const requestLogger = require('../../../shared/middleware/requestLogger');
const paymentRoutes = require('./routes/payment.routes');

const app = express();
const PORT = process.env.PORT || 3004;

// Middleware
app.use(helmet());
const corsOptions = require('../../../shared/config/cors');
app.use(cors(corsOptions()));

// Webhook endpoint needs raw body
app.use('/api/payments/webhook', express.raw({ type: 'application/json' }));

// Other routes use JSON parser
app.use(express.json());
app.use(requestLogger('payment-service'));
app.use(morgan('combined'));

// Health check
app.get('/health', (req, res) => {
  res.json({
    service: 'payment-service',
    status: 'healthy',
    port: PORT,
    timestamp: new Date().toISOString(),
  });
});

// Routes
app.use('/api/payments', paymentRoutes);

// Error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.statusCode || 500).json({
    success: false,
    message: err.message || 'Internal server error',
  });
});

app.listen(PORT, () => {
  console.log(`💳 Payment Service running on port ${PORT}`);
});

module.exports = app;
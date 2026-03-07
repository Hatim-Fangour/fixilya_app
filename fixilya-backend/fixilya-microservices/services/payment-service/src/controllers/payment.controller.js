const paymentService = require('../services/payment.service');
const axios = require('axios');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const AUTH_SERVICE_URL = process.env.AUTH_SERVICE_URL || 'http://localhost:3001';
const BOOKING_SERVICE_URL = process.env.BOOKING_SERVICE_URL || 'http://localhost:3003';

// Authenticate via Auth Service
const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];

    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const response = await axios.get(`${AUTH_SERVICE_URL}/api/auth/validate`, {
      headers: { Authorization: `Bearer ${token}` },
      timeout: 5000,
    });

    req.user = response.data.data;
    next();
  } catch (error) {
    res.status(401).json({ success: false, message: 'Invalid token' });
  }
};

exports.createPaymentIntent = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { bookingId, amount, currency = 'mad' } = req.body;

    if (!bookingId || !amount) {
      return res.status(400).json({
        success: false,
        message: 'Booking ID and amount required',
      });
    }

    const paymentIntent = await paymentService.createPaymentIntent({
      userId,
      bookingId,
      amount,
      currency,
    });

    res.status(201).json({
      success: true,
      data: {
        clientSecret: paymentIntent.clientSecret,
        paymentIntentId: paymentIntent.id,
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.confirmPayment = async (req, res, next) => {
  try {
    const { paymentIntentId } = req.body;

    const payment = await paymentService.confirmPayment(paymentIntentId);

    // Update booking payment status via Booking Service
    if (payment.status === 'succeeded') {
      await axios.patch(`${BOOKING_SERVICE_URL}/api/bookings/${payment.bookingId}/payment`, {
        paymentStatus: 'paid',
        finalPrice: payment.amount,
      }, {
        headers: { Authorization: req.headers.authorization },
        timeout: 5000,
      }).catch(err => console.error('Failed to update booking:', err.message));
    }

    res.json({
      success: true,
      data: payment,
    });
  } catch (error) {
    next(error);
  }
};

exports.getPaymentHistory = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { limit = 20, offset = 0 } = req.query;

    const payments = await paymentService.getPaymentHistory(userId, {
      limit: parseInt(limit),
      offset: parseInt(offset),
    });

    res.json({
      success: true,
      data: payments,
    });
  } catch (error) {
    next(error);
  }
};

exports.handleWebhook = async (req, res) => {
  const sig = req.headers['stripe-signature'];

  if (!sig) {
    return res.status(400).json({ error: 'Missing stripe-signature header' });
  }

  if (!process.env.STRIPE_WEBHOOK_SECRET) {
    console.error('STRIPE_WEBHOOK_SECRET not configured');
    return res.status(500).json({ error: 'Webhook not configured' });
  }

  try {
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );

    switch (event.type) {
      case 'payment_intent.succeeded':
        await paymentService.handlePaymentSuccess(event.data.object);
        break;
      case 'payment_intent.payment_failed':
        await paymentService.handlePaymentFailure(event.data.object);
        break;
      default:
        console.log(`Unhandled event type ${event.type}`);
    }

    res.json({ received: true });
  } catch (error) {
    console.error('Webhook signature verification failed:', error.message);
    res.status(400).json({ error: 'Webhook signature verification failed' });
  }
};

exports.authenticate = authenticate;

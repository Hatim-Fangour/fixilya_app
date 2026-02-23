const paymentService = require('../services/payment.service');
const axios = require('axios');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Authenticate via Auth Service
const authenticate = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];
    
    if (!token) {
      return res.status(401).json({ success: false, message: 'No token provided' });
    }

    const response = await axios.get('http://localhost:3001/api/auth/validate', {
      headers: { Authorization: `Bearer ${token}` },
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
      await axios.patch(`http://localhost:3003/api/bookings/${payment.bookingId}/payment`, {
        paymentStatus: 'paid',
        finalPrice: payment.amount,
      }, {
        headers: { Authorization: req.headers.authorization },
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
  
  try {
    const event = stripe.webhooks.constructEvent(
      req.body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET
    );

    console.log('Stripe webhook event:', event.type);

    // Handle different event types
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
    console.error('Webhook error:', error.message);
    res.status(400).send(`Webhook Error: ${error.message}`);
  }
};

exports.authenticate = authenticate;
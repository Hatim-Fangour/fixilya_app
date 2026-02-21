const { db } = require('../config/firebase');
const logger = require('../utils/logger');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Create payment intent
exports.createPaymentIntent = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { bookingId, amount, currency = 'mad' } = req.body;

    if (!bookingId || !amount) {
      return res.status(400).json({
        success: false,
        message: 'Booking ID and amount are required',
      });
    }

    // Verify booking exists and user is the client
    const bookingDoc = await db.collection('bookings').doc(bookingId).get();

    if (!bookingDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'Booking not found',
      });
    }

    const bookingData = bookingDoc.data();

    if (bookingData.clientId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Access denied',
      });
    }

    // Create Stripe payment intent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(amount * 100), // Stripe uses cents
      currency: currency.toLowerCase(),
      metadata: {
        bookingId,
        userId,
      },
    });

    // Save payment record
    const paymentData = {
      bookingId,
      userId,
      amount,
      currency,
      status: 'pending',
      paymentIntentId: paymentIntent.id,
      createdAt: new Date(),
    };

    const paymentRef = await db.collection('payments').add(paymentData);

    logger.info(`Payment intent created: ${paymentIntent.id}`);

    res.status(201).json({
      success: true,
      data: {
        paymentId: paymentRef.id,
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Confirm payment
exports.confirmPayment = async (req, res, next) => {
  try {
    const { paymentIntentId } = req.body;

    if (!paymentIntentId) {
      return res.status(400).json({
        success: false,
        message: 'Payment intent ID is required',
      });
    }

    // Get payment intent from Stripe
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

    // Update payment record
    const paymentsSnapshot = await db.collection('payments')
      .where('paymentIntentId', '==', paymentIntentId)
      .limit(1)
      .get();

    if (paymentsSnapshot.empty) {
      return res.status(404).json({
        success: false,
        message: 'Payment record not found',
      });
    }

    const paymentDoc = paymentsSnapshot.docs[0];
    const paymentData = paymentDoc.data();

    await paymentDoc.ref.update({
      status: paymentIntent.status === 'succeeded' ? 'completed' : 'failed',
      updatedAt: new Date(),
    });

    // Update booking payment status
    if (paymentIntent.status === 'succeeded') {
      await db.collection('bookings').doc(paymentData.bookingId).update({
        paymentStatus: 'paid',
        finalPrice: paymentData.amount,
        updatedAt: new Date(),
      });
    }

    logger.info(`Payment ${paymentIntentId} status: ${paymentIntent.status}`);

    res.json({
      success: true,
      data: {
        status: paymentIntent.status,
        amount: paymentIntent.amount / 100,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Get payment history
exports.getPaymentHistory = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { limit = 20, offset = 0 } = req.query;

    const snapshot = await db.collection('payments')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(parseInt(limit))
      .offset(parseInt(offset))
      .get();

    const payments = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt.toDate().toISOString(),
    }));

    res.json({
      success: true,
      data: {
        payments,
        total: payments.length,
      },
    });
  } catch (error) {
    next(error);
  }
};
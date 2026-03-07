const admin = require('../../../../shared/config/firebase');
const db = admin.firestore();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

class PaymentService {
  async createPaymentIntent({ userId, bookingId, amount, currency }) {
    try {
      // Verify booking exists
      const bookingDoc = await db.collection('bookings').doc(bookingId).get();

      if (!bookingDoc.exists) {
        throw new Error('Booking not found');
      }

      const booking = bookingDoc.data();

      if (booking.clientId !== userId) {
        throw new Error('Access denied');
      }

      // Create Stripe payment intent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: Math.round(amount * 100), // Convert to cents
        currency: currency.toLowerCase(),
        metadata: {
          bookingId,
          userId,
        },
      });

      // Save payment record
      const paymentData = {
        userId,
        bookingId,
        amount,
        currency,
        status: 'pending',
        paymentIntentId: paymentIntent.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const paymentRef = await db.collection('payments').add(paymentData);

      return {
        id: paymentRef.id,
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
      };
    } catch (error) {
      throw new Error(`Payment creation failed: ${error.message}`);
    }
  }

  async confirmPayment(paymentIntentId) {
    try {
      const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);

      // Update payment record
      const paymentsSnapshot = await db.collection('payments')
        .where('paymentIntentId', '==', paymentIntentId)
        .limit(1)
        .get();

      if (paymentsSnapshot.empty) {
        throw new Error('Payment record not found');
      }

      const paymentDoc = paymentsSnapshot.docs[0];
      const payment = paymentDoc.data();

      const status = paymentIntent.status === 'succeeded' ? 'completed' : 'failed';

      await paymentDoc.ref.update({
        status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        id: paymentDoc.id,
        status: paymentIntent.status,
        amount: paymentIntent.amount / 100,
        bookingId: payment.bookingId,
      };
    } catch (error) {
      throw new Error(`Payment confirmation failed: ${error.message}`);
    }
  }

  async getPaymentHistory(userId, options = {}) {
    try {
      const { limit = 20, offset = 0 } = options;

      const snapshot = await db.collection('payments')
        .where('userId', '==', userId)
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .offset(offset)
        .get();

      const payments = snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          ...data,
          createdAt: data.createdAt?.toDate().toISOString(),
        };
      });

      return {
        payments,
        total: payments.length,
      };
    } catch (error) {
      throw new Error(`Failed to get payment history: ${error.message}`);
    }
  }

  async handlePaymentSuccess(paymentIntent) {
    try {
      console.log('Payment succeeded:', paymentIntent.id);

      const paymentsSnapshot = await db.collection('payments')
        .where('paymentIntentId', '==', paymentIntent.id)
        .limit(1)
        .get();

      if (!paymentsSnapshot.empty) {
        const paymentDoc = paymentsSnapshot.docs[0];
        await paymentDoc.ref.update({
          status: 'completed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error('Error handling payment success:', error);
    }
  }

  async handlePaymentFailure(paymentIntent) {
    try {
      console.log('Payment failed:', paymentIntent.id);

      const paymentsSnapshot = await db.collection('payments')
        .where('paymentIntentId', '==', paymentIntent.id)
        .limit(1)
        .get();

      if (!paymentsSnapshot.empty) {
        const paymentDoc = paymentsSnapshot.docs[0];
        await paymentDoc.ref.update({
          status: 'failed',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } catch (error) {
      console.error('Error handling payment failure:', error);
    }
  }
}

module.exports = new PaymentService();
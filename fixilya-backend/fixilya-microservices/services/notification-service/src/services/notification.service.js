const admin = require('../config/firebase');
const db = admin.firestore();

// Lazy singletons — only created when actually sending email/SMS,
// so the service starts even without Twilio/SMTP env vars configured.
let _emailTransporter = null;
let _twilioClient = null;

function getEmailTransporter() {
  if (!_emailTransporter) {
    const nodemailer = require('nodemailer');
    _emailTransporter = nodemailer.createTransport({
      host: process.env.EMAIL_HOST,
      port: process.env.EMAIL_PORT,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASSWORD,
      },
    });
  }
  return _emailTransporter;
}

function getTwilioClient() {
  if (!_twilioClient) {
    const twilio = require('twilio');
    _twilioClient = twilio(
      process.env.TWILIO_ACCOUNT_SID,
      process.env.TWILIO_AUTH_TOKEN,
    );
  }
  return _twilioClient;
}

class NotificationService {
  async sendPushNotification({ userId, title, message, data = {} }) {
    try {
      // Get user's FCM token
      const userDoc = await db.collection('users').doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return { success: false, message: 'No FCM token' };
      }

      // Send via FCM
      const notification = {
        token: fcmToken,
        notification: { title, body: message },
        data,
        android: { priority: 'high' },
        apns: { headers: { 'apns-priority': '10' } },
      };

      await admin.messaging().send(notification);

      // Save to database
      await db.collection('notifications').add({
        userId,
        title,
        message,
        data,
        type: 'push',
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Push notification sent to ${userId}`);
      return { success: true };
    } catch (error) {
      console.error('Push notification error:', error);
      return { success: false, error: error.message };
    }
  }

  async sendEmail({ to, subject, html }) {
    try {
      const mailOptions = {
        from: process.env.EMAIL_FROM || 'noreply@fixilya.com',
        to,
        subject,
        html,
      };

      await getEmailTransporter().sendMail(mailOptions);

      console.log(`Email sent to ${to}`);
      return { success: true };
    } catch (error) {
      console.error('Email error:', error);
      return { success: false, error: error.message };
    }
  }

  async sendSMS({ to, message }) {
    try {
      await getTwilioClient().messages.create({
        body: message,
        from: process.env.TWILIO_PHONE_NUMBER,
        to,
      });

      console.log(`SMS sent to ${to}`);
      return { success: true };
    } catch (error) {
      console.error('SMS error:', error);
      return { success: false, error: error.message };
    }
  }

  async sendNotification({ userId, type, title, message, data = {} }) {
    try {
      // Get user preferences
      const userDoc = await db.collection('users').doc(userId).get();
      const user = userDoc.data();

      const results = {};

      // Send push notification
      if (user?.preferences?.pushNotifications !== false) {
        results.push = await this.sendPushNotification({ userId, title, message, data });
      }

      // Send email notification
      if (user?.preferences?.emailNotifications && user?.email) {
        results.email = await this.sendEmail({
          to: user.email,
          subject: title,
          html: `<h2>${title}</h2><p>${message}</p>`,
        });
      }

      // Send SMS notification
      if (user?.preferences?.smsNotifications && user?.phone) {
        results.sms = await this.sendSMS({
          to: user.phone,
          message: `${title}: ${message}`,
        });
      }

      return {
        success: true,
        results,
      };
    } catch (error) {
      console.error('Notification error:', error);
      return {
        success: false,
        error: error.message,
      };
    }
  }

  async getUnreadCount(userId) {
    try {
      const snapshot = await db
        .collection('notifications')
        .where('userId', '==', userId)
        .where('read', '==', false)
        .count()
        .get();

      return snapshot.data().count;
    } catch (error) {
      throw new Error(`Failed to get unread count: ${error.message}`);
    }
  }

  async getNotifications(userId, options = {}) {
    try {
      const { limit = 20, offset = 0, unreadOnly = false } = options;

      let query = db.collection('notifications')
        .where('userId', '==', userId);

      if (unreadOnly) {
        query = query.where('read', '==', false);
      }

      const snapshot = await query
        .orderBy('createdAt', 'desc')
        .limit(limit)
        .offset(offset)
        .get();

      const notifications = snapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          ...data,
          createdAt: data.createdAt?.toDate().toISOString(),
        };
      });

      return notifications;
    } catch (error) {
      throw new Error(`Failed to get notifications: ${error.message}`);
    }
  }

  async markAsRead(notificationId, userId) {
    try {
      const notifDoc = await db.collection('notifications').doc(notificationId).get();

      if (!notifDoc.exists) {
        throw new Error('Notification not found');
      }

      if (notifDoc.data().userId !== userId) {
        throw new Error('Access denied');
      }

      await notifDoc.ref.update({
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (error) {
      throw new Error(`Failed to mark as read: ${error.message}`);
    }
  }

  async updateFCMToken(userId, fcmToken) {
    try {
      await db.collection('users').doc(userId).update({
        fcmToken,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true };
    } catch (error) {
      throw new Error(`Failed to update FCM token: ${error.message}`);
    }
  }
}

module.exports = new NotificationService();
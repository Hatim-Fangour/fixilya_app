const { db, admin } = require('../config/firebase');
const logger = require('../utils/logger');

exports.sendNotification = async ({ userId, type, title, message, data = {} }) => {
  try {
    // Save notification to Firestore
    const notificationData = {
      userId,
      type,
      title,
      message,
      data,
      read: false,
      createdAt: new Date(),
    };

    await db.collection('notifications').add(notificationData);

    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    // Send push notification if token exists
    if (fcmToken) {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title,
          body: message,
        },
        data,
        android: {
          priority: 'high',
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
        },
      });

      logger.info(`Push notification sent to user ${userId}`);
    }

    return { success: true };
  } catch (error) {
    logger.error('Notification error:', error);
    // Don't throw - notification failure shouldn't break the main flow
    return { success: false, error: error.message };
  }
};
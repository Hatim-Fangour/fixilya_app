const notificationService = require('../services/notification.service');

// POST /api/notifications/register-token
// Body: { fcmToken: string }
exports.registerToken = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      return res.status(400).json({ success: false, message: 'fcmToken is required' });
    }

    await notificationService.updateFCMToken(userId, fcmToken.trim());

    res.json({ success: true, message: 'FCM token registered' });
  } catch (err) {
    next(err);
  }
};

// DELETE /api/notifications/remove-token
// Body: { fcmToken: string }
exports.removeToken = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      return res.status(400).json({ success: false, message: 'fcmToken is required' });
    }

    // Clear token from Firestore by setting to null
    const admin = require('../config/firebase');
    const db = admin.firestore();
    await db.collection('users').doc(userId).update({
      fcmToken: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({ success: true, message: 'FCM token removed' });
  } catch (err) {
    next(err);
  }
};

// GET /api/notifications
// Query: ?limit=20&unreadOnly=false
exports.getNotifications = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const unreadOnly = req.query.unreadOnly === 'true';

    const notifications = await notificationService.getNotifications(userId, {
      limit,
      unreadOnly,
    });

    res.json({ success: true, data: notifications });
  } catch (err) {
    next(err);
  }
};

// GET /api/notifications/unread-count
exports.getUnreadCount = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const count = await notificationService.getUnreadCount(userId);
    res.json({ success: true, count });
  } catch (err) {
    next(err);
  }
};

// PUT /api/notifications/:id/read
exports.markAsRead = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { id } = req.params;

    if (!id) {
      return res.status(400).json({ success: false, message: 'Notification ID required' });
    }

    await notificationService.markAsRead(id, userId);
    res.json({ success: true, message: 'Marked as read' });
  } catch (err) {
    next(err);
  }
};

// PUT /api/notifications/read-all
exports.markAllAsRead = async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const admin = require('../config/firebase');
    const db = admin.firestore();

    const snapshot = await db
      .collection('notifications')
      .where('userId', '==', userId)
      .where('read', '==', false)
      .get();

    if (snapshot.empty) {
      return res.json({ success: true, message: 'No unread notifications', updated: 0 });
    }

    const batch = db.batch();
    snapshot.docs.forEach((doc) => {
      batch.update(doc.ref, {
        read: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
    await batch.commit();

    res.json({ success: true, message: 'All notifications marked as read', updated: snapshot.size });
  } catch (err) {
    next(err);
  }
};

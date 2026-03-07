const express = require('express');
const router = express.Router();
const path = require('path');
const { authenticate } = require(path.join(__dirname, '../../../../shared/middleware/auth'));
const admin = require(path.join(__dirname, '../../../../shared/config/firebase'));

const db = admin.firestore();

/**
 * POST /api/notifications/register-token
 *
 * Stores the device's FCM token in Firestore so the backend can send
 * push notifications to this device.
 *
 * Body: { fcmToken: string }
 */
router.post('/register-token', authenticate, async (req, res) => {
  try {
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      return res.status(400).json({ success: false, message: 'fcmToken is required' });
    }

    await db.collection('users').doc(req.user.uid).update({
      fcmToken: fcmToken.trim(),
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({ success: true, message: 'FCM token registered' });
  } catch (err) {
    console.error('[FCM] register-token error:', err.message);
    return res.status(500).json({ success: false, message: 'Failed to register token' });
  }
});

/**
 * DELETE /api/notifications/remove-token
 *
 * Clears the FCM token on logout so the device stops receiving notifications.
 *
 * Body: { fcmToken: string }
 */
router.delete('/remove-token', authenticate, async (req, res) => {
  try {
    const { fcmToken } = req.body;

    if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim() === '') {
      return res.status(400).json({ success: false, message: 'fcmToken is required' });
    }

    await db.collection('users').doc(req.user.uid).update({
      fcmToken: admin.firestore.FieldValue.delete(),
      fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.json({ success: true, message: 'FCM token removed' });
  } catch (err) {
    console.error('[FCM] remove-token error:', err.message);
    return res.status(500).json({ success: false, message: 'Failed to remove token' });
  }
});

module.exports = router;

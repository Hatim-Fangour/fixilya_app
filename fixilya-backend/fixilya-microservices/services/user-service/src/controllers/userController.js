const { db } = require('../config/firebase');
const cloudinaryService = require('../services/cloudinaryService');
const logger = require('../utils/logger');

exports.deleteAccount = async (req, res, next) => {
  try {
    const userId = req.user.uid;

    // Get user data to find images
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      return res.status(404).json({
        success: false,
        message: 'User not found',
      });
    }

    const userData = userDoc.data();
    const imagesToDelete = [];

    // Collect profile picture
    if (userData.profilePicture) {
      const publicId = extractPublicId(userData.profilePicture);
      if (publicId) imagesToDelete.push(publicId);
    }

    // Collect work images (for handymen)
    if (userData.workImages && Array.isArray(userData.workImages)) {
      userData.workImages.forEach(url => {
        const publicId = extractPublicId(url);
        if (publicId) imagesToDelete.push(publicId);
      });
    }

    // Delete images from Cloudinary
    if (imagesToDelete.length > 0) {
      await cloudinaryService.deleteMultipleImages(imagesToDelete);
      logger.info(`Deleted ${imagesToDelete.length} images for user ${userId}`);
    }

    // Delete user from Firestore (cascade handled by rules)
    await db.collection('users').doc(userId).delete();

    // Delete from type-specific collection
    if (userData.userType === 'handyman') {
      await db.collection('handymen').doc(userId).delete();
    } else {
      await db.collection('clients').doc(userId).delete();
    }

    logger.info(`User account deleted: ${userId}`);

    res.json({
      success: true,
      message: 'Account deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};

function extractPublicId(url) {
  try {
    const parts = url.split('/');
    const fileWithExt = parts[parts.length - 1];
    const publicId = parts.slice(-2).join('/').split('.')[0];
    return publicId;
  } catch (error) {
    return null;
  }
}
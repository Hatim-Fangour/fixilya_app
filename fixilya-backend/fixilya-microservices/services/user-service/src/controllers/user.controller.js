const userService = require('../services/user.service');
const logger = require('../../../../shared/utils/logger');

// Complete profile with skip
exports.completeProfileWithSkip = async (req, res, next) => {
  try {
    const { uid, userType } = req.body;

    const result = await userService.completeProfileWithSkip({
      uid,
      userType,
    });

    logger.info(`Profile completed with skip for user: ${uid}`);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ✅ NEW: Complete full profile
exports.completeProfile = async (req, res, next) => {
  try {
    const {
      uid,
      userType,
      fullName,
      phone,
      city,
      experience,
      hourlyRate,
      bio,
      skills,
      profilePicture,
      workImages,
    } = req.body;

    const result = await userService.completeProfile({
      uid,
      userType,
      fullName,
      phone,
      city,
      experience,
      hourlyRate,
      bio,
      skills,
      profilePicture,
      workImages,
    });

    console.log(`✅ Full profile completed for user: ${uid}`);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// Get user profile
exports.getProfile = async (req, res, next) => {
  try {
    const { uid } = req.user; // From auth middleware

    const profile = await userService.getProfile(uid);

    res.json({
      success: true,
      data: profile,
    });
  } catch (error) {
    next(error);
  }
};

// Update user profile
exports.updateProfile = async (req, res, next) => {
  try {
    const { uid } = req.user; // From auth middleware
    const updates = req.body;

    const result = await userService.updateProfile(uid, updates);

    logger.info(`Profile updated for user: ${uid}`);

    res.json(result);
  } catch (error) {
    next(error);
  }
};


// ✅ Get handyman profile
exports.getHandymanProfile = async (req, res, next) => {
  try {
    const { uid } = req.user; // From auth middleware

    const profile = await userService.getHandymanProfile(uid);

    logger.info(`✅ Handyman profile retrieved for user: ${uid}`);
    logger.info(`✅ Handyman profile data: ${JSON.stringify(profile)}`);

    res.json({
      success: true,
      data: profile,
    });
  } catch (error) {
    next(error);
  }
};

// ✅ Get rating stats
exports.getRatingStats = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const stats = await userService.getRatingStats(uid);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

// ✅ Get handyman stats
exports.getHandymanStats = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const stats = await userService.getHandymanStats(uid);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

// ✅ Update handyman profile
exports.updateHandymanProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;

    const result = await userService.updateHandymanProfile(uid, updates);

    logger.info(`Profile updated for user: ${uid}`);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ✅ Update availability
exports.updateAvailability = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { isAvailable } = req.body;

    const result = await userService.updateAvailabilityStatus(uid, isAvailable);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ✅ Get availability
exports.getAvailability = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const availability = await userService.getAvailabilityStatus(uid);

    res.json({
      success: true,
      data: availability,
    });
  } catch (error) {
    next(error);
  }
};



/**
 * Get handyman settings
 */
exports.getHandymanSettings = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const settings = await userService.getHandymanSettings(uid);
    
    res.json({
      success: true,
      data: settings,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update handyman settings
 */
exports.updateHandymanSettings = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;
    
    await userService.updateHandymanSettings(uid, updates);
    
    res.json({
      success: true,
      message: 'Settings updated successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update profile picture
 */
exports.updateProfilePicture = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { profilePicture } = req.body;
    
    await userService.updateProfilePicture(uid, profilePicture);
    
    res.json({
      success: true,
      message: 'Profile picture updated successfully',
      data: { profilePicture },
    });
  } catch (error) {
    next(error);
  }
};
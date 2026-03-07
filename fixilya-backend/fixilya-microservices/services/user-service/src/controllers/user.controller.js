const userService = require("../services/user.service");
const logger      = require("../../../../shared/utils/logger");
const audit       = require("../../../../shared/utils/auditLogger");

const SVC = 'user-service';

// ─────────────────────────────────────────────
// PROFILE COMPLETION  (no auth token required — called right after sign-up)
// ─────────────────────────────────────────────

/**
 * POST /users/complete-profile-skip
 * Creates a minimal profile so the user can proceed without filling everything in.
 */
exports.completeProfileWithSkip = async (req, res, next) => {
  try {
    const { uid, userType } = req.body;

    const result = await userService.completeProfileWithSkip({ uid, userType });

    logger.info(`✅ Profile-skip complete for uid=${uid}`);
    audit.log(SVC, 'PROFILE_SKIP_COMPLETE', { actor: audit.actor(req), uid, userType });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
};

/**
 * POST /users/complete-profile
 * Saves the full onboarding profile (with Cloudinary image URLs).
 */
exports.completeProfile = async (req, res, next) => {
  try {
    const {
      uid,
      userType,
      fullName,
      phone,
      city,
      experience,
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
      bio,
      skills,
      profilePicture,
      workImages,
    });

    logger.info(`✅ Full profile complete for uid=${uid}`);
    audit.log(SVC, 'PROFILE_COMPLETE', {
      actor: audit.actor(req),
      uid,
      userType,
      city,
      hasProfilePicture: !!profilePicture,
      workImagesCount:   workImages?.length ?? 0,
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// GENERAL PROFILE  (auth required)
// ─────────────────────────────────────────────

/**
 * GET /users/profile
 * Returns the merged profile for any user type.
 */
exports.getProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const profile = await userService.getProfile(uid);

    res.json({
      success: true,
      data: profile,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /users/profile
 * Updates general profile fields (works for both clients and handymen).
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;

    const result = await userService.updateProfile(uid, updates);

    logger.info(`✅ Profile updated for uid=${uid}`);
    audit.log(SVC, 'PROFILE_UPDATE', {
      actor:  audit.actor(req),
      uid,
      fields: Object.keys(updates),
    });

    res.json(result);
  } catch (error) {
    next(error);
  }
};
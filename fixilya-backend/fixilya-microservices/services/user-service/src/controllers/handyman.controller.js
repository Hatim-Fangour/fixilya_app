const handymanService = require("../services/handyman.service");
const logger = require("../../../../shared/utils/logger");

// ─────────────────────────────────────────────
// BROWSE  (public — no auth required)
// ─────────────────────────────────────────────

/**
 * GET /handyman/all
 * Returns all approved, non-suspended handymen.
 */
exports.getAllHandymen = async (req, res, next) => {
  try {
    const handymen = await handymanService.getAllHandymen();

    res.status(200).json({
      success: true,
      data: handymen,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /handyman/nearby?lat=33.57&lon=-7.59&radius=50
 * Returns approved handymen near the given coordinates.
 * Public endpoint — no auth token required.
 */
exports.getNearbyHandymen = async (req, res, next) => {
  try {
    const lat = parseFloat(req.query.lat);
    const lon = parseFloat(req.query.lon);
    const radius = parseFloat(req.query.radius) || 50;

    if (isNaN(lat) || isNaN(lon)) {
      return res.status(400).json({
        success: false,
        message: "lat and lon query parameters are required and must be numbers",
      });
    }

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return res.status(400).json({
        success: false,
        message: "lat must be between -90 and 90, lon between -180 and 180",
      });
    }

    if (radius <= 0 || radius > 500) {
      return res.status(400).json({
        success: false,
        message: "radius must be between 1 and 500 km",
      });
    }

    const handymen = await handymanService.getNearbyHandymen(lat, lon, radius);

    res.status(200).json({
      success: true,
      count: handymen.length,
      data: handymen,
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────

/**
 * GET /handyman/profile
 * Returns the full handyman profile (handymen + users collections merged).
 */
exports.getHandymanProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const profile = await handymanService.getHandymanProfile(uid);

    logger.info(`✅ Handyman profile returned for: ${uid}`);
    console.log(`✅ Handyman profile returned for: ${uid}`);

    res.status(200).json({
      success: true,
      data: profile,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /handyman/profile
 * Updates handyman profile fields (protected fields are stripped automatically).
 */
exports.updateHandymanProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;

    const result = await handymanService.updateHandymanProfile(uid, updates);

    logger.info(`✅ Handyman profile update done for: ${uid}`);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /handyman/profile-picture
 * Updates only the profile picture URL.
 */
exports.updateProfilePicture = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { profilePicture } = req.body;

    const result = await handymanService.updateProfilePicture(
      uid,
      profilePicture,
    );

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// AVAILABILITY
// ─────────────────────────────────────────────

/**
 * PUT /handyman/availability
 * Toggles availability status.
 */
exports.updateAvailability = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { isAvailable } = req.body;

    const result = await handymanService.updateAvailabilityStatus(
      uid,
      isAvailable,
    );

    res.json(result);
  } catch (error) {
    next(error);
  }
};

/**
 * GET /handyman/availability
 * Returns current availability status.
 */
exports.getAvailability = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const availability = await handymanService.getAvailabilityStatus(uid);

    res.json({
      success: true,
      data: availability,
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// STATS & RATINGS
// ─────────────────────────────────────────────

/**
 * GET /handyman/stats
 * Returns earnings, booking counts, rating, and completed jobs.
 */
exports.getHandymanStats = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const stats = await handymanService.getHandymanStats(uid);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /handyman/rating-stats
 * Returns average rating and review count only.
 */
exports.getRatingStats = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const stats = await handymanService.getRatingStats(uid);

    res.json({
      success: true,
      data: stats,
    });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// SETTINGS
// ─────────────────────────────────────────────

/**
 * GET /handyman/settings
 * Returns notification preferences and basic account info.
 */
exports.getHandymanSettings = async (req, res, next) => {
  try {
    const { uid } = req.user;

    const settings = await handymanService.getHandymanSettings(uid);

    res.json({
      success: true,
      data: settings,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /handyman/settings
 * Updates notification preferences (whitelist-based, safe to call freely).
 */
exports.updateHandymanSettings = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;

    const result = await handymanService.updateHandymanSettings(uid, updates);

    // Fire-and-forget: notify confirmed-booking clients when phone is first revealed
    if (result.phoneRevealed) {
      handymanService.notifyClientsPhoneRevealed(uid);
    }

    res.json(result);
  } catch (error) {
    next(error);
  }
};

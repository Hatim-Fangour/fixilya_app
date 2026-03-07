const clientService = require("../services/client.service");
const logger = require("../../../../shared/utils/logger");

// ─────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────

/**
 * GET /users/client/profile
 */
exports.getProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const profile = await clientService.getProfile(uid);
    res.json({ success: true, data: profile });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /users/client/profile
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const updates = req.body;
    const result = await clientService.updateProfile(uid, updates);
    logger.info(`✅ Client profile updated uid=${uid}`);
    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// STATS
// ─────────────────────────────────────────────

/**
 * GET /users/client/stats
 */
exports.getStats = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const stats = await clientService.getStats(uid);
    res.json({ success: true, data: stats });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// BOOKINGS
// ─────────────────────────────────────────────

/**
 * GET /users/client/bookings
 */
exports.getBookings = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const limit = parseInt(req.query.limit) || 5;
    const status = req.query.status;

    const bookings = await clientService.getBookings(uid, { limit, status });
    res.json({ success: true, data: bookings });
  } catch (error) {
    next(error);
  }
};

// ─────────────────────────────────────────────
// FAVORITES
// ─────────────────────────────────────────────

/**
 * GET /users/client/favorites
 */
exports.getFavorites = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const favorites = await clientService.getFavorites(uid);
    res.json({ success: true, data: favorites });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /users/client/favorites/:handymanId
 */
exports.addFavorite = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { handymanId } = req.params;
    const result = await clientService.addFavorite(uid, handymanId);
    res.json(result);
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /users/client/favorites/:handymanId
 */
exports.removeFavorite = async (req, res, next) => {
  try {
    const { uid } = req.user;
    const { handymanId } = req.params;
    const result = await clientService.removeFavorite(uid, handymanId);
    res.json(result);
  } catch (error) {
    next(error);
  }
};
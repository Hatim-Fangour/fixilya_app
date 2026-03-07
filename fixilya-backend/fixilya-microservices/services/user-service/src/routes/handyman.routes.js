const express = require("express");
const router = express.Router();
const { body } = require("express-validator");
const handymanController = require("../controllers/handyman.controller");
const { authenticate } = require("../../../../shared/middleware/auth");
const { validate } = require("../../../../shared/middleware/validate");

// ─────────────────────────────────────────────
// All routes below require a valid Firebase JWT.
// The `authenticate` middleware attaches `req.user = { uid, ... }`.
// ─────────────────────────────────────────────

// ── Browse (no auth — clients need this before logging in) ───────────────────

/**
 * GET /handyman/all
 * Returns all approved, non-suspended handymen.
 * Public endpoint — no auth token required.
 */
router.get("/all", handymanController.getAllHandymen);

/**
 * GET /handyman/nearby?lat=33.57&lon=-7.59&radius=50
 * Returns approved handymen near given coordinates, respecting location privacy.
 * Public endpoint — no auth token required.
 */
router.get("/nearby", handymanController.getNearbyHandymen);

// ── Profile ───────────────────────────────────────────────────────────────────

/**
 * GET /handyman/profile
 * Returns the full handyman profile.
 */
router.get("/profile", authenticate, handymanController.getHandymanProfile);

/**
 * PUT /handyman/profile
 * Updates handyman profile fields.
 */
router.put(
  "/profile",
  authenticate,
  [
    body("fullName").optional().notEmpty().withMessage("Full name cannot be empty"),
    body("phone").optional().notEmpty().withMessage("Phone cannot be empty"),
    body("city").optional().notEmpty().withMessage("City cannot be empty"),
    body("experience").optional(),
    body("bio").optional(),
    body("skills").optional().isArray().withMessage("Skills must be an array"),
    body("workImages").optional().isArray().withMessage("workImages must be an array"),
    validate,
  ],
  handymanController.updateHandymanProfile
);

/**
 * PUT /handyman/profile-picture
 * Updates only the profile picture URL (Cloudinary URL expected).
 */
router.put(
  "/profile-picture",
  authenticate,
  [
    body("profilePicture")
      .notEmpty()
      .withMessage("Profile picture URL is required")
      .isURL()
      .withMessage("Must be a valid URL"),
    validate,
  ],
  handymanController.updateProfilePicture
);

// ── Availability ──────────────────────────────────────────────────────────────

/**
 * GET /handyman/availability
 * Returns current availability status and last update timestamp.
 */
router.get("/availability", authenticate, handymanController.getAvailability);

/**
 * PUT /handyman/availability
 * Toggles availability on / off.
 */
router.put(
  "/availability",
  authenticate,
  [
    body("isAvailable")
      .isBoolean()
      .withMessage("isAvailable must be a boolean"),
    validate,
  ],
  handymanController.updateAvailability
);

// ── Stats & Ratings ───────────────────────────────────────────────────────────

/**
 * GET /handyman/stats
 * Returns full stats: earnings, booking counts, rating, completed jobs.
 */
router.get("/stats", authenticate, handymanController.getHandymanStats);

/**
 * GET /handyman/rating-stats
 * Returns average rating and total review count only.
 */
router.get("/rating-stats", authenticate, handymanController.getRatingStats);

// ── Settings ──────────────────────────────────────────────────────────────────

/**
 * GET /handyman/settings
 * Returns notification preferences and basic account info.
 */
router.get("/settings", authenticate, handymanController.getHandymanSettings);

/**
 * PUT /handyman/settings
 * Updates notification preferences (pushNotifications, emailNotifications, smsNotifications).
 */
router.put(
  "/settings",
  authenticate,
  [
    body("pushNotifications")
      .optional()
      .isBoolean()
      .withMessage("pushNotifications must be a boolean"),
    body("emailNotifications")
      .optional()
      .isBoolean()
      .withMessage("emailNotifications must be a boolean"),
    body("smsNotifications")
      .optional()
      .isBoolean()
      .withMessage("smsNotifications must be a boolean"),
    validate,
  ],
  handymanController.updateHandymanSettings
);

module.exports = router;
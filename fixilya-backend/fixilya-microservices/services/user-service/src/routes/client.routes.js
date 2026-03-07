const express = require("express");
const router = express.Router();
const { body } = require("express-validator");
const clientController = require("../controllers/client.controller");
const { authenticate } = require("../../../../shared/middleware/auth");
const { validate } = require("../../../../shared/middleware/validate");

// All routes require a valid Firebase token
router.use(authenticate);

// ─────────────────────────────────────────────
// PROFILE
// ─────────────────────────────────────────────

/**
 * GET /users/client/profile
 */
router.get("/profile", clientController.getProfile);

/**
 * PUT /users/client/profile
 */
router.put(
  "/profile",
  [
    body("fullName").optional().notEmpty().withMessage("Name cannot be empty"),
    body("phone").optional(),
    body("city").optional(),
    body("address").optional(),
    validate,
  ],
  clientController.updateProfile
);

// ─────────────────────────────────────────────
// STATS
// ─────────────────────────────────────────────

/**
 * GET /users/client/stats
 * Returns { totalBookings, favoritesCount }
 */
router.get("/stats", clientController.getStats);

// ─────────────────────────────────────────────
// BOOKINGS
// ─────────────────────────────────────────────

/**
 * GET /users/client/bookings?limit=5&status=all
 */
router.get("/bookings", clientController.getBookings);

// ─────────────────────────────────────────────
// FAVORITES
// ─────────────────────────────────────────────

/**
 * GET /users/client/favorites
 */
router.get("/favorites", clientController.getFavorites);

/**
 * POST /users/client/favorites/:handymanId
 */
router.post("/favorites/:handymanId", clientController.addFavorite);

/**
 * DELETE /users/client/favorites/:handymanId
 */
router.delete("/favorites/:handymanId", clientController.removeFavorite);

module.exports = router;
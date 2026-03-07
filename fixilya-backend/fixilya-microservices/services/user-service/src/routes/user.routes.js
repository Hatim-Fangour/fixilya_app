const express = require("express");
const router = express.Router();
const { body } = require("express-validator");
const userController = require("../controllers/user.controller");
const { authenticate } = require("../../../../shared/middleware/auth");
const { validate } = require("../../../../shared/middleware/validate");

// ─────────────────────────────────────────────
// Mount all /handyman/* routes from their own router.
// This keeps user.routes.js focused and handyman logic self-contained.
// ─────────────────────────────────────────────
const handymanRoutes = require("./handyman.routes");
const clientRoutes   = require("./client.routes");

router.use("/handyman", handymanRoutes);
router.use("/client",   clientRoutes);


// ─────────────────────────────────────────────
// PROFILE COMPLETION  (auth required — UID must match token)
// ─────────────────────────────────────────────

/**
 * Middleware: ensure body.uid matches the authenticated user.
 */
const enforceOwnership = (req, res, next) => {
  if (req.body.uid && req.body.uid !== req.user.uid) {
    return res.status(403).json({
      success: false,
      message: "You can only modify your own profile",
    });
  }
  // If no uid in body, inject it from the token
  if (!req.body.uid) {
    req.body.uid = req.user.uid;
  }
  next();
};

/**
 * POST /users/complete-profile-skip
 * Creates a minimal profile so the user can move past onboarding immediately.
 */
router.post(
  "/complete-profile-skip",
  authenticate,
  [
    body("uid").optional(),
    body("userType")
      .isIn(["handyman", "client", "customer"])
      .withMessage("Invalid user type"),
    validate,
  ],
  enforceOwnership,
  userController.completeProfileWithSkip
);

/**
 * POST /users/complete-profile
 * Saves the full onboarding profile (accepts Cloudinary image URLs).
 */
router.post(
  "/complete-profile",
  authenticate,
  [
    body("uid").optional(),
    body("userType")
      .isIn(["handyman", "client", "customer"])
      .withMessage("Invalid user type"),
    body("fullName").notEmpty().withMessage("Full name is required"),
    body("phone").optional(),
    body("city").optional(),
    body("experience").optional(),
    body("bio").optional(),
    body("skills").optional().isArray().withMessage("Skills must be an array"),
    body("profilePicture").optional().isString(),
    body("workImages").optional().isArray().withMessage("workImages must be an array"),
    validate,
  ],
  enforceOwnership,
  userController.completeProfile
);

// ─────────────────────────────────────────────
// GENERAL PROFILE  (auth required)
// ─────────────────────────────────────────────

/**
 * GET /users/profile
 * Returns the merged profile for any user type.
 */
router.get("/profile", authenticate, userController.getProfile);

/**
 * PUT /users/profile
 * Updates basic profile info (works for clients and handymen alike).
 */
router.put(
  "/profile",
  authenticate,
  [
    body("fullName").optional().notEmpty().withMessage("Full name cannot be empty"),
    body("phone").optional().notEmpty().withMessage("Phone cannot be empty"),
    body("city").optional().notEmpty().withMessage("City cannot be empty"),
    validate,
  ],
  userController.updateProfile
);

module.exports = router;
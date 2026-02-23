const express = require("express");
const router = express.Router();
const { body, param } = require("express-validator");
const authController = require("../controllers/auth.controller");
const { validate } = require("../../../../shared/middleware/validate");
const { authenticate } = require("../../../../shared/middleware/auth");

// Validation rules
const registerValidation = [
  body("email").isEmail().withMessage("Valid email required").trim().toLowerCase(),
  body("password")
    .isLength({ min: 6 })
    .withMessage("Password must be 6+ characters"),
  body("fullName").notEmpty().withMessage("Full name required"),
  body("phone").isMobilePhone().withMessage("Valid phone required"),
  body("userType")
    .isIn(["client", "customer", "handyman"])
    .withMessage("Invalid user type"),
];

const completeRegistrationValidation = [
  body("uid").notEmpty().withMessage("User ID required"),
  body("fullName").notEmpty().withMessage("Full name required"),
  body("phone").isMobilePhone().withMessage("Valid phone required"),
  body("userType")
    .isIn(["customer", "handyman", "client"])
    .withMessage("Invalid user type"),
];

const loginValidation = [
  body('email')
    .isEmail()
    .withMessage('Please provide a valid email')
    .trim()
    .toLowerCase(),
  body('password')
    .notEmpty()
    .withMessage('Password is required')
    .isLength({ min: 6 })
    .withMessage('Password must be at least 6 characters'),
];

// Routes
router.post("/register", registerValidation, validate, authController.register);
router.post(
  "/complete-registration",
  completeRegistrationValidation,
  validate,
  authController.completeRegistration,
);
router.get(
  "/check-verification/:uid",
  [param("uid").notEmpty(), validate],
  authController.checkEmailVerification,
);

router.post(
  "/resend-verification",
  [body("uid").notEmpty(), validate],
  authController.resendVerificationEmail,
);

router.post("/login", loginValidation, validate, authController.login);
router.post(
  "/refresh",
  [body("refreshToken").notEmpty(), validate],
  authController.refreshToken,
);
router.get("/validate", authController.validateToken);
router.post(
  "/logout",
  [body("refreshToken").optional(), validate],
  authController.logout,
);


// Change password
router.put(
  '/change-password',
  authenticate,
  [
    body('currentPassword').notEmpty().withMessage('Current password is required'),
    body('newPassword').isLength({ min: 6 }).withMessage('New password must be at least 6 characters'),
    validate,
  ],
  authController.changePassword
);

// Delete account
router.delete('/delete-account', authenticate, authController.deleteAccount);


module.exports = router;

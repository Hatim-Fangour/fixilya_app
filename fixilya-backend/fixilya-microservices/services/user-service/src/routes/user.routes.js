const express = require('express');
const router = express.Router();
const { body } = require('express-validator');
const userController = require('../controllers/user.controller');
const { authenticate } = require('../../../../shared/middleware/auth');
const { validate } = require('../../../../shared/middleware/validate');

// ✅ Complete profile with skip (doesn't need auth - user just registered)
router.post('/complete-profile-skip',
  [
    body('uid').notEmpty().withMessage('User ID is required'),
    body('userType').isIn(['handyman', 'client', 'customer']).withMessage('Invalid user type'),
    validate,
  ],
  userController.completeProfileWithSkip
);

// ✅ NEW: Complete full profile
router.post('/complete-profile',
  [
    body('uid').notEmpty().withMessage('User ID is required'),
    body('userType').isIn(['handyman', 'client', 'customer']).withMessage('Invalid user type'),
    body('fullName').notEmpty().withMessage('Full name is required'),
    body('phone').optional(),
    body('city').optional(),
    body('experience').optional(),
    body('hourlyRate').optional().isNumeric(),
    body('bio').optional(),
    body('skills').optional().isArray(),
    body('profilePicture').optional().isString(), // ✅ URL string
    body('workImages').optional().isArray(), // ✅ Array of URL strings
    validate,
  ],
  userController.completeProfile
);


// Get own profile
router.get('/profile', authenticate, userController.getProfile);

// Update own profile
router.put('/profile',
  authenticate,
  [
    body('fullName').optional().notEmpty(),
    body('phone').optional().notEmpty(),
    body('city').optional().notEmpty(),
    validate,
  ],
  userController.updateProfile
);


// Get handyman profile
router.get('/handyman/profile', authenticate, userController.getHandymanProfile);

// Get handyman rating stats
router.get('/handyman/rating-stats', authenticate, userController.getRatingStats);

// Get handyman stats (bookings, earnings, etc.)
router.get('/handyman/stats', authenticate, userController.getHandymanStats);

// Update handyman profile
router.put('/handyman/profile',
  authenticate,
  [
    body('fullName').optional().notEmpty(),
    body('phone').optional().notEmpty(),
    body('city').optional().notEmpty(),
    body('experience').optional(),
    body('hourlyRate').optional().isNumeric(),
    body('bio').optional(),
    body('skills').optional().isArray(),
    body('workImages').optional().isArray(),
    validate,
  ],
  userController.updateHandymanProfile
);

// Update availability status
router.put('/handyman/availability',
  authenticate,
  [
    body('isAvailable').isBoolean().withMessage('isAvailable must be a boolean'),
    validate,
  ],
  userController.updateAvailability
);

// Get availability status
router.get('/handyman/availability', authenticate, userController.getAvailability);

// ==========================================
// GENERAL USER ROUTES (Auth Required)
// ==========================================

// Get own profile (for any user type)
router.get('/profile', authenticate, userController.getProfile);

// Update own profile (for any user type)
router.put('/profile',
  authenticate,
  [
    body('fullName').optional().notEmpty(),
    body('phone').optional().notEmpty(),
    body('city').optional().notEmpty(),
    validate,
  ],
  userController.updateProfile
);

// Get handyman settings
router.get('/handyman/settings', authenticate, userController.getHandymanSettings);

// Update handyman settings
router.put('/handyman/settings',
  authenticate,
  [
    body('pushNotifications').optional().isBoolean(),
    body('emailNotifications').optional().isBoolean(),
    body('smsNotifications').optional().isBoolean(),
    validate,
  ],
  userController.updateHandymanSettings
);

// Update profile picture
router.put('/handyman/profile-picture',
  authenticate,
  [
    body('profilePicture').notEmpty().withMessage('Profile picture URL is required'),
    validate,
  ],
  userController.updateProfilePicture
);


module.exports = router;
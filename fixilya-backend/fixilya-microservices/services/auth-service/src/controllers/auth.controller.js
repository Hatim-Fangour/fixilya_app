const path = require('path');
// const { auth } = require(path.join(__dirname, '../../../../shared/config/firebase'));
const logger = require(path.join(__dirname, '../../../../shared/utils/logger'));
const authService = require('../services/auth.service');

exports.register = async (req, res, next) => {
  try {
    const { email, password, fullName, phone, userType } = req.body;

    const result = await authService.register({
      email,
      password,
      fullName,
      phone,
      userType,
    });

    logger.info(`User registered: ${email}`);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    console.log('📝 Login request for:', email);

    // ✅ Add timeout wrapper
    const loginPromise = authService.login(email, password);
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Login request timeout - please try again')), 25000);
    });

    const result = await Promise.race([loginPromise, timeoutPromise]);

    logger.info(`User logged in: ${email}`);

    res.json({
      success: true,
      message: 'Login successful',
      data: result,
    });
  } catch (error) {
    console.error('❌ Login controller error:', error.message);
    next(error);
  }
};

exports.refreshToken = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    const result = await authService.refreshAccessToken(refreshToken);

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

exports.validateToken = async (req, res, next) => {
  try {
    const token = req.headers.authorization?.split('Bearer ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided',
      });
    }

    const decoded = await auth.verifyIdToken(token);

    res.json({
      success: true,
      data: {
        valid: true,
        uid: decoded.uid,
        email: decoded.email,
      },
    });
  } catch (error) {
    res.status(401).json({
      success: false,
      message: 'Invalid token',
    });
  }
};

exports.logout = async (req, res, next) => {
  try {
    const { refreshToken } = req.body;

    if (refreshToken) {
      await authService.revokeRefreshToken(refreshToken);
    }

    res.json({
      success: true,
      message: 'Logged out successfully',
    });
  } catch (error) {
    next(error);
  }
};

// Complete registration after email verification
exports.completeRegistration = async (req, res, next) => {
  try {
    const { uid, fullName, phone, userType } = req.body;

    const result = await authService.completeRegistration({
      uid,
      fullName,
      phone,
      userType,
    });

    logger.info(`Registration completed for user: ${uid}`);

    res.json({
      success: true,
      message: result.message,
      data: result.userData,
    });
  } catch (error) {
    next(error);
  }
};

// Check email verification status
exports.checkEmailVerification = async (req, res, next) => {
  try {
    const { uid } = req.params;

    const result = await authService.checkEmailVerification(uid);

    res.json({
      success: true,
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// Resend verification email
exports.resendVerificationEmail = async (req, res, next) => {
  try {
    const { uid } = req.body;

    const result = await authService.resendVerificationEmail(uid);

    logger.info(`Verification email resent to user: ${uid}`);

    res.json({
      success: true,
      message: result.message,
      data: {
        verificationLink: result.verificationLink,
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Change password
 */
exports.changePassword = async (req, res, next) => {
  try {
    const { uid, email } = req.user;
    const { currentPassword, newPassword } = req.body;

    await authService.changePassword(email, currentPassword, newPassword);

    res.json({
      success: true,
      message: 'Password changed successfully',
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Delete account
 */
exports.deleteAccount = async (req, res, next) => {
  try {
    const { uid } = req.user;

    await authService.deleteAccount(uid);

    res.json({
      success: true,
      message: 'Account deleted successfully',
    });
  } catch (error) {
    next(error);
  }
};
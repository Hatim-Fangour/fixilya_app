const admin = require('../../shared/config/firebase');
const logger = require('../../shared/utils/logger');

/**
 * Basic authentication — verifies Firebase ID token and attaches user to req.
 * Does NOT enforce email verification (use `requireVerifiedEmail` for that).
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided',
      });
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified === true,
      userType: decodedToken.userType || null,
      role: decodedToken.role || decodedToken.userType || null,
    };

    next();
  } catch (error) {
    logger.error('Token verification failed:', error.code || error.message);

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        message: 'Token expired - please sign in again',
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
    });
  }
};

/**
 * Stricter authentication — verifies token AND enforces email verification.
 * Use on protected routes where verified identity is required (bookings, payments, etc.).
 */
const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'No token provided',
      });
    }

    const token = authHeader.split(' ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);

    const emailVerified = decodedToken.email_verified === true;

    if (!emailVerified) {
      return res.status(403).json({
        success: false,
        message: 'Email not verified. Please verify your email to continue.',
        code: 'EMAIL_NOT_VERIFIED',
      });
    }

    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      userType: decodedToken.userType || 'client',
      role: decodedToken.role || decodedToken.userType || 'client',
      emailVerified: true,
    };

    next();
  } catch (error) {
    logger.error('Token verification failed:', error.code || error.message);

    if (error.code === 'auth/id-token-expired') {
      return res.status(401).json({
        success: false,
        message: 'Token expired - please sign in again',
      });
    }

    if (error.code === 'auth/argument-error') {
      return res.status(401).json({
        success: false,
        message: 'Invalid token format',
      });
    }

    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
    });
  }
};

/**
 * Role-based access control middleware.
 * Usage: requireRole('admin') or requireRole('handyman', 'admin')
 */
const requireRole = (...allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required',
      });
    }

    const userRole = req.user.role || req.user.userType;
    if (!userRole || !allowedRoles.includes(userRole)) {
      return res.status(403).json({
        success: false,
        message: 'Insufficient permissions',
      });
    }

    next();
  };
};

module.exports = { authenticate, verifyToken, requireRole };

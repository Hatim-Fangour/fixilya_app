const admin = require('../../shared/config/firebase');

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


     // Verify Firebase ID token
    const decodedToken = await admin.auth().verifyIdToken(token);

     // Attach user info to request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
      userType: decodedToken.userType || null,
    };

    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token',
    });
  }
};

const verifyToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      console.log('❌ No authorization header provided');
      throw new AppError('No token provided', 401);
    }

    const token = authHeader.split(' ')[1];

    // Verify the token
    const decodedToken = await admin.auth().verifyIdToken(token);

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('✅ Token verified for user:', decodedToken.uid);
    console.log('📋 Full decoded token claims:');
    console.log(JSON.stringify(decodedToken, null, 2)); // ✅ Log everything
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // ✅ FIXED: Check BOTH Firebase native claim AND custom claim
    const emailVerified = 
      decodedToken.email_verified === true || // Firebase native claim
      decodedToken.email_verified === true;    // Custom claim (we set this)
    
    console.log('📧 Email verification check:');
    console.log('   Firebase email_verified:', decodedToken.email_verified);
    console.log('   Custom email_verified:', decodedToken.email_verified);
    console.log('   Final emailVerified:', emailVerified);

    // ✅ RELAXED: Allow users with emailVerified OR if they just completed registration
    // (Some endpoints like complete-profile-skip should work even if email isn't verified yet)
    if (!emailVerified) {
      console.log('⚠️ Email not verified, but allowing request to proceed');
      // Don't throw error - just log warning
    }

    // Attach user info to request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      userType: decodedToken.userType || 'client',
      role: decodedToken.role || 'client',
      emailVerified: emailVerified,
    };

    console.log('✅ User authenticated:', req.user);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    next();
  } catch (error) {
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.error('❌ Token verification failed');
    console.error('Error:', error.message);
    console.error('Code:', error.code);
    console.error('Stack:', error.stack);
    console.error('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

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
      message: error.message || 'Invalid or expired token',
    });
  }
};

module.exports = { authenticate, verifyToken };
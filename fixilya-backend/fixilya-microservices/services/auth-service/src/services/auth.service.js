const path = require('path');
const { admin, auth, db } = require(path.join(__dirname, '../../../../shared/config/firebase'));
const redisClient = require(path.join(__dirname, '../../../../shared/config/redis'));

class AuthService {
  async register({ email, password, fullName, phone, userType }) {
    try {
      // Create user in Firebase Auth
      const userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: false,
      });

      // Set custom claims
      await auth.setCustomUserClaims(userRecord.uid, { userType });

      // Create user document in Firestore
      await db.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        email,
        fullName,
        phone,
        userType,
        emailVerified: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create type-specific document
      const collection = userType === 'handyman' ? 'handymen' : 'clients';
      await db.collection(collection).doc(userRecord.uid).set({
        uid: userRecord.uid,
        fullName,
        phone,
        email,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Generate tokens
      const customToken = await auth.createCustomToken(userRecord.uid);

      return {
        uid: userRecord.uid,
        email: userRecord.email,
        accessToken: customToken,
      };
    } catch (error) {
      throw new Error(`Registration failed: ${error.message}`);
    }
  }

  async login(email, password) {
    try {
      // Use Firebase REST API to verify credentials
      const response = await fetch(
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${process.env.FIREBASE_WEB_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            email,
            password,
            returnSecureToken: true,
          }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error?.message || 'Invalid credentials');
      }

      // Get user data
      const userDoc = await db.collection('users').doc(data.localId).get();
      
      if (!userDoc.exists) {
        throw new Error('User data not found');
      }

      const userData = userDoc.data();

      return {
        uid: data.localId,
        email: data.email,
        accessToken: data.idToken,
        refreshToken: data.refreshToken,
        expiresIn: data.expiresIn,
        userType: userData.userType,
      };
    } catch (error) {
      throw new Error(`Login failed: ${error.message}`);
    }
  }

  async refreshAccessToken(refreshToken) {
    try {
      const response = await fetch(
        `https://securetoken.googleapis.com/v1/token?key=${process.env.FIREBASE_WEB_API_KEY}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            grant_type: 'refresh_token',
            refresh_token: refreshToken,
          }),
        }
      );

      const data = await response.json();

      if (!response.ok) {
        throw new Error('Invalid refresh token');
      }

      return {
        accessToken: data.id_token,
        refreshToken: data.refresh_token,
        expiresIn: data.expires_in,
      };
    } catch (error) {
      throw new Error(`Token refresh failed: ${error.message}`);
    }
  }

  async revokeRefreshToken(refreshToken) {
    // Firebase automatically handles token revocation
    return true;
  }
}

module.exports = new AuthService();
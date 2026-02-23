// const admin = require('../config/firebase');const { AppError } = require("../../../../shared/utils/appError");
const logger = require("../../../../shared/utils/logger");
const { getAuth, signInWithEmailAndPassword } = require("firebase/auth");
const { initializeApp, getApps } = require("firebase/app");

const { AppError } = require("../../../../shared/utils/appError");
const admin = require("./../../../../shared/config/firebase");
const sgMail = require("@sendgrid/mail");

sgMail.setApiKey(process.env.SENDGRID_API_KEY);

console.log("🔑 AuthService initialized with Firebase and SendGrid");
// console.log(process.env.SENDGRID_API_KEY);

const auth = admin.auth();
const db = admin.firestore();

// Initialize Firebase Client SDK (for password verification)
let clientAuth;
function getClientAuth() {
  if (!clientAuth) {
    const existingApps = getApps();
    const clientApp =
      existingApps.find((app) => app.name === "client-auth") ||
      initializeApp(
        {
          apiKey: process.env.FIREBASE_API_KEY,
          authDomain: process.env.FIREBASE_AUTH_DOMAIN,
          projectId: process.env.FIREBASE_PROJECT_ID,
        },
        "client-auth",
      );

    clientAuth = getAuth(clientApp);
  }
  return clientAuth;
}

class AuthService {
  async register({ email, password, fullName, phone, userType }) {
    try {
      // Validate userType
      const validUserTypes = ["client", "customer", "handyman", "admin"];

      if (!validUserTypes.includes(userType)) {
        throw new AppError("Invalid user type", 400);
      }

      // Normalize: both "client" and "customer" become "client"
      const normalizedUserType =
        userType.toLowerCase() === "customer" || userType.toLowerCase() === "client"
          ? "client"
          : userType.toLowerCase();

      // Create Firebase user
      const userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        phoneNumber: phone,
      });

      // Set custom claims
      await auth.setCustomUserClaims(userRecord.uid, {
        userType: normalizedUserType,
        role: normalizedUserType,
        // email_verified: true,
      });

      // Create minimal user document in Firestore
      await db.collection("users").doc(userRecord.uid).set({
        email,
        userType: normalizedUserType,
        createdAt: new Date().toISOString(),
      });

      // Create minimal type-specific document
      const typeCollection =
        normalizedUserType === "handyman" ? "handymen" : "clients";

      await db.collection(typeCollection).doc(userRecord.uid).set({
        approved: false,
        suspended: false,
        createdAt: new Date().toISOString(),
      });

      // Generate email verification link
      const verificationLink = await auth.generateEmailVerificationLink(email);

      // ✅ UPDATED: Only send email if SendGrid is configured
      let emailSent = false;
      if (process.env.SENDGRID_API_KEY && process.env.SENDGRID_FROM_EMAIL) {
        console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        console.log("📧 SENDING VERIFICATION EMAIL");
        console.log("To:", email);
        console.log("From:", process.env.SENDGRID_FROM_EMAIL);
        console.log("From Name:", process.env.SENDGRID_FROM_NAME);

        const msg = {
          to: email,
          from: {
            email: process.env.SENDGRID_FROM_EMAIL, // ✅ Use .env variable
            name: process.env.SENDGRID_FROM_NAME || "Fixilya Team",
          },
          subject: "✅ Verify Your Fixilya Account",
          html: `
            <!DOCTYPE html>
            <html>
            <head>
              <style>
                body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
                .button { display: inline-block; background: #667eea; color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; margin: 20px 0; font-weight: bold; }
                .footer { text-align: center; margin-top: 20px; color: #666; font-size: 12px; }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <h1>Welcome to Fixilya! 🎉</h1>
                </div>
                <div class="content">
                  <h2>Hi ${fullName},</h2>
                  <p>Thanks for signing up! We're excited to have you on board.</p>
                  <p>To complete your registration, please verify your email address:</p>
                  
                  <div style="text-align: center;">
                    <a href="${verificationLink}" class="button">Verify Email Address</a>
                  </div>
                  
                  <p>Or copy this link: <br><small>${verificationLink}</small></p>
                  
                  <p><strong>This link expires in 24 hours.</strong></p>
                  
                  <p>Best regards,<br>The Fixilya Team</p>
                </div>
                <div class="footer">
                  <p>&copy; 2026 Fixilya. All rights reserved.</p>
                </div>
              </div>
            </body>
            </html>
          `,
        };

        try {
          const response = await sgMail.send(msg);
          console.log("✅ Verification email sent successfully");
          console.log("Status Code:", response[0].statusCode);
          console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
          emailSent = true;
        } catch (error) {
          console.error("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
          console.error("❌ SENDGRID ERROR");
          console.error("Error Code:", error.code);
          console.error("Error Message:", error.message);

          // ✅ Log detailed errors
          if (error.response?.body?.errors) {
            console.error("SendGrid Errors:");
            error.response.body.errors.forEach((err, index) => {
              console.error(`  ${index + 1}. ${err.message}`);
              if (err.field) console.error(`     Field: ${err.field}`);
              if (err.help) console.error(`     Help: ${err.help}`);
            });
          }
          console.error("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

          // ✅ Don't fail registration if email fails
          console.warn("⚠️ Email failed to send, but registration succeeded");
        }
      } else {
        console.warn("⚠️ SendGrid not configured - skipping email");
      }

      return {
        uid: userRecord.uid,
        email,
        fullName,
        phone,
        userType: normalizedUserType,
        verificationLink,
        emailSent, // ✅ Tell client if email was sent
        emailVerified: false,
      };
    } catch (error) {
      if (error.code === "auth/email-already-exists") {
        throw new AppError("Email already exists", 400);
      }
      if (error.code === "auth/invalid-phone-number") {
        throw new AppError("Invalid phone number", 400);
      }
      if (error.code === "auth/phone-number-already-exists") {
        throw new AppError("Phone number already in use", 400);
      }
      throw error;
    }
  }

  async completeRegistration({ uid, fullName, phone, userType }) {
  try {
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("📝 COMPLETING REGISTRATION");
    console.log("UID:", uid);
    console.log("User Type:", userType);
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    // Check if user exists and email is verified
    const userRecord = await auth.getUser(uid);

    if (!userRecord.emailVerified) {
      throw new AppError("Email not verified", 403);
    }

    console.log("✅ Email verified:", userRecord.emailVerified);

    // ✅ CRITICAL: Update Firebase user to mark email as verified (in case it's not)
    await auth.updateUser(uid, {
      emailVerified: true,
    });
    console.log("✅ Firebase user emailVerified set to true");

    // ✅ Set custom claims with email_verified
    const normalizedUserType = userType === "customer" ? "client" : userType;
    await auth.setCustomUserClaims(uid, {
      userType: normalizedUserType,
      role: normalizedUserType,
      email_verified: true, // ✅ CRITICAL
    });
    console.log("✅ Custom claims set:", {
      userType: normalizedUserType,
      role: normalizedUserType,
      email_verified: true,
    });

    // ✅ Update users collection with full profile
    await db.collection("users").doc(uid).update({
      fullName,
      phone,
      emailVerified: true,
      isActive: true,
      suspended: false,
      updatedAt: new Date().toISOString(),
    });
    console.log("✅ Users collection updated");

    // ✅ Update type-specific collection with full profile
    const typeCollection = userType === "handyman" ? "handymen" : "clients";

    await db.collection(typeCollection).doc(uid).update({
      fullName,
      phone,
      profileCompleted: false,
      updatedAt: new Date().toISOString(),
    });
    console.log(`✅ ${typeCollection} collection updated`);

    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    console.log("✅ REGISTRATION COMPLETE");
    console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

    return {
      success: true,
      message: "Registration completed successfully",
      userData: {
        uid,
        email: userRecord.email,
        fullName,
        phone,
        userType: normalizedUserType,
        emailVerified: true,
      },
    };
  } catch (error) {
    console.error("❌ Error completing registration:", error);
    if (error.code === "auth/user-not-found") {
      throw new AppError("User not found", 404);
    }
    throw error;
  }
}

  async checkEmailVerification(uid) {
    try {
      const userRecord = await auth.getUser(uid);

      return {
        verified: userRecord.emailVerified,
        email: userRecord.email,
      };
    } catch (error) {
      throw new AppError("User not found", 404);
    }
  }

  async resendVerificationEmail(uid) {
    try {
      const userRecord = await auth.getUser(uid);

      if (userRecord.emailVerified) {
        throw new AppError("Email already verified", 400);
      }

      const verificationLink = await auth.generateEmailVerificationLink(
        userRecord.email,
      );

      return {
        success: true,
        message: "Verification email sent",
        verificationLink,
      };
    } catch (error) {
      throw error;
    }
  }

  async login(email, password) {
    let clientAuthInstance = null;

    try {
      console.log("🔐 Attempting login for:", email);

      try {
        console.log("🔑 Verifying password...");

        clientAuthInstance = getClientAuth();

        const verificationPromise = signInWithEmailAndPassword(
          clientAuthInstance,
          email,
          password,
        );

        const timeoutPromise = new Promise((_, reject) => {
          setTimeout(
            () => reject(new Error("Password verification timeout")),
            10000,
          );
        });

        const userCredential = await Promise.race([
          verificationPromise,
          timeoutPromise,
        ]);

        console.log("✅ Password verified successfully");

        const uid = userCredential.user.uid;

        const userDoc = await db.collection("users").doc(uid).get();

        if (!userDoc.exists) {
          throw new AppError("User profile not found", 404);
        }

        const userData = userDoc.data();

        if (userData.suspended === true) {
          throw new AppError(
            "Your account has been suspended. Please contact support.",
            403,
          );
        }

        if (userData.userType === "handyman") {
          const handymanDoc = await db.collection("handymen").doc(uid).get();
          if (handymanDoc.exists) {
            const handymanData = handymanDoc.data();

            if (handymanData.rejected === true) {
              throw new AppError("Your handyman application was rejected", 403);
            }

            userData.pendingApproval = handymanData.approved !== true;
          }
        }

        try {
          await db.collection("users").doc(uid).update({
            lastLogin: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (e) {
          console.warn("⚠️ Could not update last login:", e.message);
        }

        const customToken = await auth.createCustomToken(uid, {
          userType: userData.userType,
          role: userData.userType,
          emailVerified: userCredential.user.emailVerified,
        });

        const refreshToken = await auth.createCustomToken(uid);

        if (clientAuthInstance) {
          try {
            const { signOut } = require("firebase/auth");
            await signOut(clientAuthInstance);
            console.log("✅ Signed out from client auth");
          } catch (e) {
            console.warn("⚠️ Could not sign out from client auth:", e.message);
          }
        }

        console.log("✅ Login successful for:", email);

        return {
          uid: uid,
          email: userData.email,
          fullName: userData.fullName,
          phone: userData.phone || "",
          userType: userData.userType,
          emailVerified: userCredential.user.emailVerified,
          pendingApproval: userData.pendingApproval || false,
          accessToken: customToken,
          refreshToken: refreshToken,
          expiresIn: 3600,
        };
      } catch (error) {
        console.error(
          "❌ Password verification failed:",
          error.code || error.message,
        );

        if (clientAuthInstance) {
          try {
            const { signOut } = require("firebase/auth");
            await signOut(clientAuthInstance);
          } catch (e) {
            // Ignore signout errors
          }
        }

        // Re-throw AppError as-is
        if (error instanceof AppError) {
          throw error;
        }

        // Handle specific Firebase errors
        if (error.message === "Password verification timeout") {
          throw new AppError(
            "Authentication service is slow. Please try again.",
            503,
          );
        }
        if (
          error.code === "auth/wrong-password" ||
          error.code === "auth/invalid-credential" ||
          error.code === "auth/invalid-login-credentials"
        ) {
          throw new AppError("Invalid email or password", 401);
        }
        if (error.code === "auth/user-not-found") {
          throw new AppError("Invalid email or password", 401);
        }
        if (error.code === "auth/too-many-requests") {
          throw new AppError(
            "Too many failed login attempts. Please try again later.",
            429,
          );
        }
        if (error.code === "auth/user-disabled") {
          throw new AppError("This account has been disabled", 403);
        }

        throw new AppError("Login failed. Please try again.", 401);
      }
    } catch (error) {
      console.error("❌ Login error:", error);

      if (clientAuthInstance) {
        try {
          const { signOut } = require("firebase/auth");
          await signOut(clientAuthInstance);
        } catch (e) {
          // Ignore
        }
      }

      // ✅ FIXED: Just re-throw!
      throw error;
    }
  }

  async refreshAccessToken(refreshToken) {
    try {
      // Verify the refresh token
      const decodedToken = await auth.verifyIdToken(refreshToken);

      // Generate new access token
      const newAccessToken = await auth.createCustomToken(decodedToken.uid);

      return {
        accessToken: newAccessToken,
        expiresIn: 3600,
      };
    } catch (error) {
      throw new AppError("Invalid refresh token", 401);
    }
  }

  async revokeRefreshToken(refreshToken) {
    try {
      const decodedToken = await auth.verifyIdToken(refreshToken);
      await auth.revokeRefreshTokens(decodedToken.uid);
      return true;
    } catch (error) {
      throw new AppError("Failed to revoke token", 400);
    }
  }

  async validateToken(token) {
    try {
      const decodedToken = await auth.verifyIdToken(token);
      return {
        valid: true,
        uid: decodedToken.uid,
        email: decodedToken.email,
        userType: decodedToken.userType,
      };
    } catch (error) {
      throw new AppError("Invalid token", 401);
    }
  }

  /**
   * Change password
   */
  async changePassword(email, currentPassword, newPassword) {
    try {
      console.log("🔐 Changing password for:", email);

      // Verify current password by attempting to sign in
      try {
        const {
          getAuth,
          signInWithEmailAndPassword,
        } = require("firebase/auth");
        const { initializeApp } = require("firebase/app");

        // Initialize Firebase client SDK
        const firebaseConfig = {
          apiKey: process.env.FIREBASE_API_KEY,
          authDomain: process.env.FIREBASE_AUTH_DOMAIN,
          projectId: process.env.FIREBASE_PROJECT_ID,
        };

        const app = initializeApp(firebaseConfig, "temp-auth-" + Date.now());
        const auth = getAuth(app);

        // Verify current password
        await signInWithEmailAndPassword(auth, email, currentPassword);
        console.log("✅ Current password verified");
      } catch (error) {
        console.error("❌ Current password verification failed:", error.code);
        if (
          error.code === "auth/wrong-password" ||
          error.code === "auth/invalid-credential"
        ) {
          throw new Error("Current password is incorrect");
        }
        throw new Error("Failed to verify current password");
      }

      // Update password using Admin SDK
      const userRecord = await admin.auth().getUserByEmail(email);
      await admin.auth().updateUser(userRecord.uid, {
        password: newPassword,
      });

      console.log("✅ Password updated successfully");
    } catch (error) {
      console.error("❌ Error changing password:", error);
      throw error;
    }
  }

  /**
   * Delete account (including Cloudinary images)
   */
  async deleteAccount(uid) {
    try {
      console.log("🗑️ Deleting account:", uid);

      // Get user data to find images
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw new Error("User not found");
      }

      const userData = userDoc.data();
      const userType = userData.userType;

      // Get type-specific data for images
      let imagesToDelete = [];
      if (userType === "handyman") {
        const handymanDoc = await db.collection("handymen").doc(uid).get();
        if (handymanDoc.exists) {
          const handymanData = handymanDoc.data();

          // Add profile picture
          if (handymanData.profilePicture) {
            imagesToDelete.push(handymanData.profilePicture);
          }

          // Add work images
          if (
            handymanData.workImages &&
            Array.isArray(handymanData.workImages)
          ) {
            imagesToDelete.push(...handymanData.workImages);
          }
        }
      } else if (userType === "client" || userType === "customer") {
        const clientDoc = await db.collection("clients").doc(uid).get();
        if (clientDoc.exists) {
          const clientData = clientDoc.data();

          // Add profile picture
          if (clientData.profilePicture) {
            imagesToDelete.push(clientData.profilePicture);
          }
        }
      }

      console.log(`📷 Found ${imagesToDelete.length} images to delete`);

      // Delete images from Cloudinary
      if (imagesToDelete.length > 0) {
        const cloudinary = require("cloudinary").v2;

        cloudinary.config({
          cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
          api_key: process.env.CLOUDINARY_API_KEY,
          api_secret: process.env.CLOUDINARY_API_SECRET,
        });

        for (const imageUrl of imagesToDelete) {
          try {
            // Extract public ID from Cloudinary URL
            const publicId = extractPublicIdFromUrl(imageUrl);
            if (publicId) {
              await cloudinary.uploader.destroy(publicId);
              console.log(`✅ Deleted image: ${publicId}`);
            }
          } catch (error) {
            console.error(
              `⚠️ Failed to delete image ${imageUrl}:`,
              error.message,
            );
            // Continue even if image deletion fails
          }
        }
      }

      // Delete Firestore documents
      await db.collection("users").doc(uid).delete();
      console.log("✅ Deleted users document");

      if (userType === "handyman") {
        await db.collection("handymen").doc(uid).delete();
        console.log("✅ Deleted handymen document");
      } else if (userType === "client" || userType === "customer") {
        await db.collection("clients").doc(uid).delete();
        console.log("✅ Deleted clients document");
      }

      // Delete Firebase Auth user
      await admin.auth().deleteUser(uid);
      console.log("✅ Deleted Firebase Auth user");

      console.log("✅ Account deletion complete");
    } catch (error) {
      console.error("❌ Error deleting account:", error);
      throw error;
    }
  }
}

/**
 * Helper: Extract Cloudinary public ID from URL
 */
function extractPublicIdFromUrl(url) {
  try {
    // Example URL: https://res.cloudinary.com/dbz3wtlbj/image/upload/v1771735265/profiles/profile_sbrdTtk1XXW4MK0FiF7hlZPwT7y2.jpg
    const match = url.match(/\/v\d+\/(.+)\.\w+$/);
    if (match && match[1]) {
      return match[1]; // Returns: profiles/profile_sbrdTtk1XXW4MK0FiF7hlZPwT7y2
    }
    return null;
  } catch (error) {
    console.error("Error extracting public ID:", error);
    return null;
  }
}

module.exports = new AuthService();

const { AppError } = require("../../../../shared/utils/appError");
const admin = require("../../../../shared/config/firebase");
const logger = require("../../../../shared/utils/logger");
const {
  HANDYMAN_COLLECTION_NAME,
  CLIENT_COLLECTION_NAME,
  USER_COLLECTION_NAME,
  ADMIN_NOTIFICATIONS_COLLECTION_NAME,
} = require("../../../../shared/config/appConstats");

const auth = admin.auth();
const db = admin.firestore();

class UserService {
  // ─────────────────────────────────────────────
  // PROFILE COMPLETION (called right after registration — no auth token yet)
  // ─────────────────────────────────────────────

  /**
   * Creates a minimal profile document so the user can proceed without
   * filling out their full profile immediately.
   * Handymen will need to complete their profile later to get approved.
   */
  async completeProfileWithSkip({ uid, userType }) {
    try {
      logger.info(`📝 [completeProfileWithSkip] uid=${uid} userType=${userType}`);

      const userRecord = await auth.getUser(uid);
      if (!userRecord) {
        throw new AppError("User not found", 404);
      }

      const normalizedUserType = userType === "customer" ? "client" : userType;
      const collection =
        normalizedUserType === "handyman"
          ? HANDYMAN_COLLECTION_NAME
          : CLIENT_COLLECTION_NAME;

      // Track whether this is the first time the doc is created
      const collectionDoc = await db.collection(collection).doc(uid).get();
      const isNewUser = !collectionDoc.exists;

      const timestamp = new Date().toISOString();

      const profileData =
        normalizedUserType === "handyman"
          ? {
              uid,
              email: userRecord.email || "",
              fullName: userRecord.displayName || "",
              phone: userRecord.phoneNumber || "",
              city: "",
              experience: "0",
              hourlyRate: 0,
              bio: "",
              skills: [],
              profilePicture: userRecord.photoURL || "",
              workImages: [],
              profileCompleted: false,
              approved: false,
              rejected: false,
              suspended: false,
              reviewStatus: "pending",
              rating: 0,
              totalReviews: 0,
              completedJobs: 0,
              createdAt: timestamp,
              updatedAt: timestamp,
            }
          : {
              uid,
              email: userRecord.email || "",
              fullName: userRecord.displayName || "",
              phone: userRecord.phoneNumber || "",
              city: "",
              profilePicture: userRecord.photoURL || "",
              profileCompleted: false,
              approved: true,
              suspended: false,
              createdAt: timestamp,
              updatedAt: timestamp,
            };

      // merge: true keeps any fields already saved (e.g. from a previous attempt)
      await db.collection(collection).doc(uid).set(profileData, { merge: true });
      logger.info(`✅ Profile created in ${collection} for uid=${uid}`);

      await db.collection(USER_COLLECTION_NAME).doc(uid).update({
        profileCompleted: false,
        updatedAt: timestamp,
      });

      await auth.setCustomUserClaims(uid, {
        userType: normalizedUserType,
        role: normalizedUserType,
      });
      logger.info(`✅ Custom claims set for uid=${uid}`);

      // Notify admin only for brand-new handymen
      if (normalizedUserType === "handyman" && isNewUser) {
        await this._notifyAdminNewHandyman({
          handymanId: uid,
          handymanName: userRecord.displayName || "Unknown",
          email: userRecord.email || "",
          phone: userRecord.phoneNumber || "",
          profileCompleted: false,
          timestamp,
        });
      }

      return {
        success: true,
        message:
          normalizedUserType === "handyman"
            ? "Profile created. Complete it later to get approved."
            : "Profile created successfully.",
        data: {
          uid,
          userType: normalizedUserType,
          profileCompleted: false,
          needsApproval: normalizedUserType === "handyman",
        },
      };
    } catch (error) {
      logger.error(`❌ [completeProfileWithSkip] ${error.message}`);
      throw error;
    }
  }

  /**
   * Saves a full profile (all fields) submitted from the onboarding screen.
   * Accepts Cloudinary URLs for profilePicture and workImages.
   */
  async completeProfile({
    uid,
    userType,
    fullName,
    phone,
    city,
    experience,
    bio,
    skills,
    profilePicture,
    workImages,
  }) {
    try {
      logger.info(`📝 [completeProfile] uid=${uid} userType=${userType}`);

      const firebaseUser = await auth.getUser(uid);
      if (!firebaseUser) {
        throw new AppError("User not found", 404);
      }

      const normalizedUserType = userType === "customer" ? "client" : userType;
      const collection =
        normalizedUserType === "handyman"
          ? HANDYMAN_COLLECTION_NAME
          : CLIENT_COLLECTION_NAME;

      const isNewUser = await this._isFirstTimeUser(uid);
      const timestamp = new Date().toISOString();

      const profileData =
        normalizedUserType === "handyman"
          ? {
              uid,
              email: firebaseUser.email || "",
              fullName: fullName || firebaseUser.displayName || "",
              phone: phone || firebaseUser.phoneNumber || "",
              city: city || "",
              experience: experience || "0",
              bio: bio || "",
              skills: skills || [],
              profilePicture: profilePicture || "",
              workImages: workImages || [],
              profileCompleted: true,
              approved: false,
              rejected: false,
              suspended: false,
              reviewStatus: "pending",
              rating: 0,
              totalReviews: 0,
              completedJobs: 0,
              createdAt: timestamp,
              updatedAt: timestamp,
            }
          : {
              uid,
              email: firebaseUser.email || "",
              fullName: fullName || firebaseUser.displayName || "",
              phone: phone || firebaseUser.phoneNumber || "",
              city: city || "",
              profilePicture: profilePicture || "",
              profileCompleted: true,
              approved: true,
              suspended: false,
              createdAt: timestamp,
              updatedAt: timestamp,
            };

      await db.collection(collection).doc(uid).set(profileData, { merge: true });
      logger.info(`✅ Full profile saved to ${collection} for uid=${uid}`);

      await db.collection(USER_COLLECTION_NAME).doc(uid).update({
        profileCompleted: true,
        fullName: fullName || firebaseUser.displayName || "",
        phone: phone || firebaseUser.phoneNumber || "",
        updatedAt: timestamp,
      });

      await auth.setCustomUserClaims(uid, {
        userType: normalizedUserType,
        role: normalizedUserType,
      });

      if (normalizedUserType === "handyman" && isNewUser) {
        await this._notifyAdminNewHandyman({
          handymanId: uid,
          handymanName: fullName || firebaseUser.displayName || "Unknown",
          email: firebaseUser.email || "",
          phone: phone || firebaseUser.phoneNumber || "",
          profileCompleted: true,
          timestamp,
        });
      }

      logger.info(
        `✅ Full profile complete for uid=${uid} | pic=${profilePicture ? "yes" : "no"} | workImages=${workImages?.length ?? 0}`
      );

      return {
        success: true,
        message:
          normalizedUserType === "handyman"
            ? isNewUser
              ? "Your profile is under review. You'll be notified once approved."
              : "Your profile has been updated successfully."
            : "Profile created successfully.",
        data: {
          uid,
          userType: normalizedUserType,
          profileCompleted: true,
          needsApproval: normalizedUserType === "handyman",
          isNewUser,
          profilePictureUrl: profilePicture || "",
          workImageUrls: workImages || [],
        },
      };
    } catch (error) {
      logger.error(`❌ [completeProfile] ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // GENERAL PROFILE (any user type)
  // ─────────────────────────────────────────────

  /**
   * Returns merged profile from users + type-specific collection.
   */
  async getProfile(uid) {
    try {
      const userDoc = await db.collection(USER_COLLECTION_NAME).doc(uid).get();

      if (!userDoc.exists) {
        throw new AppError("User not found", 404);
      }

      const userData = userDoc.data();
      const userType = userData.userType;
      const collection =
        userType === "handyman" ? HANDYMAN_COLLECTION_NAME : CLIENT_COLLECTION_NAME;

      const profileDoc = await db.collection(collection).doc(uid).get();

      return {
        ...userData,
        ...(profileDoc.exists ? profileDoc.data() : {}),
      };
    } catch (error) {
      logger.error(`❌ [getProfile] uid=${uid}: ${error.message}`);
      throw error;
    }
  }

  /**
   * Updates general profile fields. Mirrors name / phone into the type-specific collection.
   */
  async updateProfile(uid, updates) {
    try {
      const userDoc = await db.collection(USER_COLLECTION_NAME).doc(uid).get();

      if (!userDoc.exists) {
        throw new AppError("User not found", 404);
      }

      const userData = userDoc.data();
      const collection =
        userData.userType === "handyman"
          ? HANDYMAN_COLLECTION_NAME
          : CLIENT_COLLECTION_NAME;

      // Strip immutable fields
      const protectedFields = ["uid", "email", "userType", "createdAt"];
      protectedFields.forEach((field) => delete updates[field]);

      updates.updatedAt = new Date().toISOString();

      await db.collection(collection).doc(uid).update(updates);

      // Mirror name / phone into users collection
      const userUpdates = {};
      if (updates.fullName) userUpdates.fullName = updates.fullName;
      if (updates.phone) userUpdates.phone = updates.phone;

      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = new Date().toISOString();
        await db.collection(USER_COLLECTION_NAME).doc(uid).update(userUpdates);
      }

      return {
        success: true,
        message: "Profile updated successfully",
      };
    } catch (error) {
      logger.error(`❌ [updateProfile] uid=${uid}: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // PRIVATE HELPERS
  // ─────────────────────────────────────────────

  /**
   * Returns true if the user was created within the last 2 minutes
   * (used to decide whether to send an admin notification).
   */
  async _isFirstTimeUser(uid) {
    try {
      const userDoc = await db.collection(USER_COLLECTION_NAME).doc(uid).get();

      if (!userDoc.exists) return true;

      const data = userDoc.data();
      if (!data?.createdAt) return true;

      const createdAt = data.createdAt.toDate
        ? data.createdAt.toDate()
        : new Date(data.createdAt);

      const diffMinutes = (Date.now() - createdAt.getTime()) / 60_000;
      return diffMinutes < 2;
    } catch {
      return false;
    }
  }

  /**
   * Creates a notification document in adminNotifications so admins can
   * review and approve new handyman registrations.
   * Failures here are logged but never rethrow — registration must not break.
   */
  async _notifyAdminNewHandyman({
    handymanId,
    handymanName,
    email,
    phone,
    profileCompleted,
    timestamp,
  }) {
    try {
      await db.collection(ADMIN_NOTIFICATIONS_COLLECTION_NAME).add({
        type: "new_handyman",
        handymanId,
        handymanName,
        email,
        phone,
        profileCompleted,
        title: profileCompleted
          ? "🎉 New Handyman — Profile Completed"
          : "📝 New Handyman — Profile Incomplete",
        message: profileCompleted
          ? `${handymanName} has registered and completed their profile. Review and approve.`
          : `${handymanName} has registered but skipped profile setup. They may complete it later.`,
        priority: profileCompleted ? "high" : "medium",
        read: false,
        actionRequired: true,
        createdAt: timestamp,
      });

      logger.info(`📧 Admin notification created for handyman: ${handymanId}`);
    } catch (error) {
      // Non-fatal — don't let notification failure break registration
      logger.error(`❌ Failed to create admin notification: ${error.message}`);
    }
  }
}

module.exports = new UserService();
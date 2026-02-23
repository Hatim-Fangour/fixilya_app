
const { AppError } = require("../../../../shared/utils/appError");
const admin = require("../../../../shared/config/firebase");
const imageUploadService = require('../utils/imageUpload');


// ✅ CRITICAL: Get auth and db from the admin instance
const auth = admin.auth();
const db = admin.firestore();


class UserService {
  async completeProfileWithSkip({ uid, userType }) {
    try {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('📝 COMPLETING PROFILE WITH SKIP');
      console.log('User ID:', uid);
      console.log('User Type:', userType);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // ✅ Check if user exists in Firebase Auth
      const userRecord = await auth.getUser(uid); // ✅ Now auth.getUser will work
      if (!userRecord) {
        throw new AppError("User not found", 404);
      }

      const normalizedUserType = userType === "customer" ? "client" : userType;
      const collection =
        normalizedUserType === "handyman" ? "handymen" : "clients";

      // Check if this is a new user
      const collectionDoc = await db.collection(collection).doc(uid).get();
      const isNewUser = !collectionDoc.exists;

      // ✅ FIXED: Use ISO timestamp instead of FieldValue.serverTimestamp()
      const timestamp = new Date().toISOString();

      // Prepare profile data
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

      // Save to collection (merge to preserve existing data)
      await db
        .collection(collection)
        .doc(uid)
        .set(profileData, { merge: true });
      console.log(`✅ Profile created in ${collection} collection`);

      // Update users collection
      await db.collection("users").doc(uid).update({
        profileCompleted: false,
        updatedAt: timestamp,
      });
      console.log("✅ Users collection updated");

      // Set custom claims
      await auth.setCustomUserClaims(uid, {
        userType: normalizedUserType,
        role: normalizedUserType,
      });
      console.log("✅ Custom claims set");

      // Create admin notification for new handymen
      if (normalizedUserType === "handyman" && isNewUser) {
        await db.collection("adminNotifications").add({
          type: "new_handyman",
          handymanId: uid,
          handymanName: userRecord.displayName || "Unknown",
          email: userRecord.email || "",
          phone: userRecord.phoneNumber || "",
          profileCompleted: false,
          reviewStatus: "pending",
          createdAt: timestamp,
          read: false,
          message: `New handyman "${userRecord.displayName || "Unknown"}" registered and needs approval.`,
        });
        console.log("✅ Admin notification created");
      }

      console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      console.log("✅ PROFILE SETUP COMPLETE");
      console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");

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
      console.error("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      console.error("❌ Error in completeProfileWithSkip:");
      console.error("Message:", error.message);
      console.error("Stack:", error.stack);
      console.error("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      throw error;
    }
  }

  // ✅ NEW: Check if user is first-time (created in last 2 minutes)
  async isFirstTimeUser(uid) {
    try {
      const userDoc = await db.collection("users").doc(uid).get();

      if (!userDoc.exists) {
        return true;
      }

      const data = userDoc.data();
      if (!data || !data.createdAt) {
        return true;
      }

      // Convert Firestore timestamp to Date
      const createdAt = data.createdAt.toDate
        ? data.createdAt.toDate()
        : new Date(data.createdAt);
      const now = new Date();
      const differenceInMinutes = (now - createdAt) / (1000 * 60);

      // If created within last 2 minutes, it's a new user
      return differenceInMinutes < 2;
    } catch (error) {
      console.error("Error checking if first-time user:", error);
      return false; // Assume not first time on error
    }
  }

  // ✅ NEW: Notify admin of new handyman
  async notifyAdminOfNewHandyman({
    handymanId,
    handymanName,
    email,
    phone,
    profileCompleted,
  }) {
    try {
      console.log("📧 Creating admin notification...");

      const notification = {
        type: "new_handyman",
        handymanId,
        handymanName,
        email,
        phone,
        profileCompleted,
        title: profileCompleted
          ? "🎉 New Handyman - Profile Completed"
          : "📝 New Handyman - Profile Incomplete",
        message: profileCompleted
          ? `${handymanName} has registered and completed their profile. Review and approve their application.`
          : `${handymanName} has registered but skipped profile setup. They may complete it later.`,
        priority: profileCompleted ? "high" : "medium",
        read: false,
        actionRequired: !profileCompleted,
        createdAt: new Date().toISOString(),
      };

      await db.collection("adminNotifications").add(notification);
      console.log("✅ Admin notification created successfully");

      return { success: true };
    } catch (error) {
      console.error("❌ Error creating admin notification:", error);
      // Don't throw - notification failure shouldn't block registration
      return { success: false, error: error.message };
    }
  }

  // ✅ NEW: Complete profile with full details
   async completeProfile({
    uid,
    userType,
    fullName,
    phone,
    city,
    experience,
    hourlyRate,
    bio,
    skills,
    profilePicture, // ✅ This is the Cloudinary URL from Flutter
    workImages, // ✅ This is array of Cloudinary URLs from Flutter
  }) {
    try {
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('📝 COMPLETING FULL PROFILE');
      console.log('User ID:', uid);
      console.log('User Type:', userType);
      console.log('Profile Picture URL:', profilePicture); // ✅ Log to verify
      console.log('Work Images URLs:', workImages); // ✅ Log to verify

      // Get Firebase Auth user
      const firebaseUser = await auth.getUser(uid);
      if (!firebaseUser) {
        throw new AppError('User not found', 404);
      }

      const normalizedUserType = userType === 'customer' ? 'client' : userType;
      const collection = normalizedUserType === 'handyman' ? 'handymen' : 'clients';

      // Check if this is a new user
      const isNewUser = await this.isFirstTimeUser(uid);
      console.log(`📊 Is new user: ${isNewUser}`);

      const timestamp = new Date().toISOString();

      // ✅ FIXED: Prepare full profile data with URLs
      const profileData = normalizedUserType === 'handyman' ? {
        uid,
        email: firebaseUser.email || '',
        fullName: fullName || firebaseUser.displayName || '',
        phone: phone || firebaseUser.phoneNumber || '',
        city: city || '',
        experience: experience || '0',
        hourlyRate: hourlyRate || 0,
        bio: bio || '',
        skills: skills || [],
        profilePicture: profilePicture || '', // ✅ Save Cloudinary URL
        workImages: workImages || [], // ✅ Save Cloudinary URLs array
        profileCompleted: true,
        approved: false,
        rejected: false,
        suspended: false,
        reviewStatus: 'pending',
        rating: 0,
        totalReviews: 0,
        completedJobs: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
      } : {
        uid,
        email: firebaseUser.email || '',
        fullName: fullName || firebaseUser.displayName || '',
        phone: phone || firebaseUser.phoneNumber || '',
        city: city || '',
        profilePicture: profilePicture || '',
        profileCompleted: true,
        approved: true,
        suspended: false,
        createdAt: timestamp,
        updatedAt: timestamp,
      };

      console.log('📝 Profile data to save:');
      console.log('   Profile Picture:', profileData.profilePicture);
      console.log('   Work Images:', profileData.workImages);

      // ✅ Save to collection
      await db.collection(collection).doc(uid).set(profileData, { merge: true });
      console.log(`✅ Profile saved to ${collection} collection`);

      // ✅ Update users collection
      await db.collection('users').doc(uid).update({
        profileCompleted: true,
        fullName: fullName || firebaseUser.displayName || '',
        phone: phone || firebaseUser.phoneNumber || '',
        updatedAt: timestamp,
      });
      console.log('✅ Users collection updated');

      // Set custom claims
      await auth.setCustomUserClaims(uid, {
        userType: normalizedUserType,
        role: normalizedUserType,
      });
      console.log('✅ Custom claims set');

      // Notify admin for new handymen only
      if (normalizedUserType === 'handyman' && isNewUser) {
        await this.notifyAdminOfNewHandyman({
          handymanId: uid,
          handymanName: fullName || firebaseUser.displayName || 'Unknown',
          email: firebaseUser.email || '',
          phone: phone || firebaseUser.phoneNumber || '',
          profileCompleted: true,
        });
      }

      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      console.log('✅ FULL PROFILE SETUP COMPLETE');
      console.log(`   Profile Picture: ${profilePicture ? '✅ Saved' : '❌ None'}`);
      console.log(`   Work Images: ${workImages?.length || 0} saved`);
      console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      return {
        success: true,
        message: normalizedUserType === 'handyman'
          ? isNewUser
            ? 'Your profile is under review. You\'ll be notified once approved.'
            : 'Your profile has been updated successfully.'
          : 'Profile created successfully.',
        data: {
          uid,
          userType: normalizedUserType,
          profileCompleted: true,
          needsApproval: normalizedUserType === 'handyman',
          isNewUser,
          profilePictureUrl: profilePicture || '', // ✅ Return the URL
          workImageUrls: workImages || [], // ✅ Return the URLs
        },
      };
    } catch (error) {
      console.error('❌ Error in completeProfile:', error);
      throw error;
    }
  }

  async getProfile(uid) {
    try {
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw new AppError("User not found", 404);
      }

      const userData = userDoc.data();
      const userType = userData.userType;
      const collection = userType === "handyman" ? "handymen" : "clients";

      const profileDoc = await db.collection(collection).doc(uid).get();

      return {
        ...userData,
        ...profileDoc.data(),
      };
    } catch (error) {
      throw error;
    }
  }

  async updateProfile(uid, updates) {
    try {
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        throw new AppError("User not found", 404);
      }

      const userData = userDoc.data();
      const collection =
        userData.userType === "handyman" ? "handymen" : "clients";

      // Remove protected fields
      delete updates.uid;
      delete updates.email;
      delete updates.userType;
      delete updates.createdAt;

      // Add timestamp
      updates.updatedAt = new Date().toISOString();

      // Update type-specific collection
      await db.collection(collection).doc(uid).update(updates);

      // Update users collection if needed
      const userUpdates = {};
      if (updates.fullName) userUpdates.fullName = updates.fullName;
      if (updates.phone) userUpdates.phone = updates.phone;

      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = new Date().toISOString();
        await db.collection("users").doc(uid).update(userUpdates);
      }

      return {
        success: true,
        message: "Profile updated successfully",
      };
    } catch (error) {
      throw error;
    }
  }


  // ✅ NEW: Get handyman profile
  async getHandymanProfile(uid) {
    try {
      console.log('🔍 Fetching handyman profile:', uid);

      const handymanDoc = await db.collection('handymen').doc(uid).get();

      if (!handymanDoc.exists) {
        throw new AppError('Handyman profile not found', 404);
      }

      const handymanData = handymanDoc.data();

      // Get user data too
      const userDoc = await db.collection('users').doc(uid).get();
      const userData = userDoc.exists ? userDoc.data() : {};

      const profile = {
        ...handymanData,
        fullName: userData.fullName || handymanData.fullName || 'Handyman',
        email: userData.email || '',
        phone: userData.phone || '',
        uid: uid,
      };

      console.log('✅ Handyman profile loaded');
      return profile;
    } catch (error) {
      console.error('❌ Error fetching handyman profile:', error);
      throw error;
    }
  }

  // ✅ NEW: Get handyman rating stats
  async getRatingStats(uid) {
    try {
      console.log('📊 Fetching rating stats for:', uid);

      const reviewsSnapshot = await db
        .collection('reviews')
        .where('handymanId', '==', uid)
        .get();

      if (reviewsSnapshot.empty) {
        return { rating: 0.0, reviewCount: 0 };
      }

      let totalRating = 0;
      const reviewCount = reviewsSnapshot.size;

      reviewsSnapshot.forEach((doc) => {
        const data = doc.data();
        totalRating += data.rating || 0;
      });

      const averageRating = parseFloat((totalRating / reviewCount).toFixed(1));

      return {
        rating: averageRating,
        reviewCount: reviewCount,
      };
    } catch (error) {
      console.error('❌ Error fetching rating stats:', error);
      return { rating: 0.0, reviewCount: 0 };
    }
  }

  // ✅ NEW: Get handyman stats (bookings, earnings, etc.)
  async getHandymanStats(uid) {
    try {
      console.log('📊 Fetching stats for handyman:', uid);

      const handymanDoc = await db.collection('handymen').doc(uid).get();

      if (!handymanDoc.exists) {
        throw new AppError('Handyman not found', 404);
      }

      const handymanData = handymanDoc.data();

      // Get bookings
      const bookingsSnapshot = await db
        .collection('bookings')
        .where('handymanId', '==', uid)
        .get();

      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      const monthAgo = new Date(today);
      monthAgo.setMonth(monthAgo.getMonth() - 1);

      let todayEarnings = 0;
      let weeklyEarnings = 0;
      let monthlyEarnings = 0;
      let activeBookings = 0;
      let completedJobs = 0;
      let pendingRequests = 0;

      bookingsSnapshot.forEach((doc) => {
        const data = doc.data();
        const status = data.status || '';
        const amount = parseFloat(data.amount || data.estimatedPrice || 0);

        switch (status) {
          case 'pending':
            pendingRequests++;
            activeBookings++;
            break;
          case 'confirmed':
          case 'in_progress':
            activeBookings++;
            break;
          case 'completed':
            completedJobs++;

            if (data.completedAt && amount > 0) {
              const completedAt = data.completedAt.toDate
                ? data.completedAt.toDate()
                : new Date(data.completedAt);
              const completedDate = new Date(
                completedAt.getFullYear(),
                completedAt.getMonth(),
                completedAt.getDate(),
              );

              if (completedDate >= today) {
                todayEarnings += amount;
              }
              if (completedDate >= weekAgo) {
                weeklyEarnings += amount;
              }
              if (completedDate >= monthAgo) {
                monthlyEarnings += amount;
              }
            }
            break;
        }
      });

      // Get reviews
      const reviewsSnapshot = await db
        .collection('reviews')
        .where('handymanId', '==', uid)
        .get();

      let averageRating = 0;
      const totalReviews = reviewsSnapshot.size;

      if (totalReviews > 0) {
        let totalRating = 0;
        reviewsSnapshot.forEach((doc) => {
          totalRating += doc.data().rating || 0;
        });
        averageRating = parseFloat((totalRating / totalReviews).toFixed(1));
      }

      const stats = {
        todayEarnings,
        weeklyEarnings,
        monthlyEarnings,
        activeBookings,
        completedJobs,
        pendingRequests,
        rating: averageRating,
        totalReviews,
      };

      console.log('✅ Stats calculated:', stats);
      return stats;
    } catch (error) {
      console.error('❌ Error fetching stats:', error);
      throw error;
    }
  }

  // ✅ NEW: Update handyman profile
  async updateHandymanProfile(uid, updates) {
    try {
      console.log('📝 Updating handyman profile:', uid);
      console.log('   Updates:', updates);

      // Remove protected fields
      delete updates.uid;
      delete updates.email;
      delete updates.createdAt;
      delete updates.approved;
      delete updates.suspended;

      // Add timestamp
      updates.updatedAt = new Date().toISOString();

      // Update handymen collection
      await db.collection('handymen').doc(uid).update(updates);

      // Update users collection if needed
      const userUpdates = {};
      if (updates.fullName) userUpdates.fullName = updates.fullName;
      if (updates.phone) userUpdates.phone = updates.phone;

      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = new Date().toISOString();
        await db.collection('users').doc(uid).update(userUpdates);
      }

      console.log('✅ Handyman profile updated successfully');

      return {
        success: true,
        message: 'Profile updated successfully',
      };
    } catch (error) {
      console.error('❌ Error updating handyman profile:', error);
      throw error;
    }
  }

  // ✅ NEW: Update availability status
  async updateAvailabilityStatus(uid, isAvailable) {
    try {
      console.log('📝 Updating availability:', uid, isAvailable);

      await db.collection('handymen').doc(uid).update({
        isAvailable: isAvailable,
        lastAvailabilityUpdate: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      console.log('✅ Availability updated successfully');

      return {
        success: true,
        message: 'Availability updated successfully',
        data: { isAvailable },
      };
    } catch (error) {
      console.error('❌ Error updating availability:', error);
      throw error;
    }
  }

  // ✅ NEW: Get availability status
  async getAvailabilityStatus(uid) {
    try {
      const doc = await db.collection('handymen').doc(uid).get();

      if (doc.exists) {
        const data = doc.data();
        return {
          isAvailable: data.isAvailable || false,
          lastUpdate: data.lastAvailabilityUpdate,
        };
      }

      return { isAvailable: false };
    } catch (error) {
      console.error('❌ Error getting availability:', error);
      return { isAvailable: false };
    }
  }

  /**
 * Get handyman settings
 */
async getHandymanSettings(uid) {
  try {
    console.log('📊 Fetching settings for handyman:', uid);

    // Get from handymen collection
    const handymanDoc = await db.collection('handymen').doc(uid).get();

    if (!handymanDoc.exists) {
      throw new Error('Handyman profile not found');
    }

    const handymanData = handymanDoc.data();

    // Get from users collection for email
    const userDoc = await db.collection('users').doc(uid).get();
    const userData = userDoc.exists ? userDoc.data() : {};

    // Return settings with defaults
    return {
      fullName: handymanData.fullName || userData.fullName || '',
      email: userData.email || '',
      phone: handymanData.phone || '',
      city: handymanData.city || '',
      profilePicture: handymanData.profilePicture || '',
      pushNotifications: handymanData.pushNotifications ?? true,
      emailNotifications: handymanData.emailNotifications ?? false,
      smsNotifications: handymanData.smsNotifications ?? true,
    };
  } catch (error) {
    console.error('❌ Error fetching handyman settings:', error);
    throw error;
  }
}

/**
 * Update handyman settings
 */
async updateHandymanSettings(uid, updates) {
  try {
    console.log('📝 Updating handyman settings:', uid);
    console.log('   Updates:', updates);

    const allowedFields = [
      'pushNotifications',
      'emailNotifications',
      'smsNotifications',
    ];

    const filteredUpdates = {};
    for (const [key, value] of Object.entries(updates)) {
      if (allowedFields.includes(key)) {
        filteredUpdates[key] = value;
      }
    }

    if (Object.keys(filteredUpdates).length === 0) {
      console.log('⚠️ No valid settings to update');
      return;
    }

    filteredUpdates.updatedAt = new Date().toISOString();

    await db.collection('handymen').doc(uid).update(filteredUpdates);

    console.log('✅ Handyman settings updated');
  } catch (error) {
    console.error('❌ Error updating handyman settings:', error);
    throw error;
  }
}

/**
 * Update profile picture
 */
async updateProfilePicture(uid, profilePictureUrl) {
  try {
    console.log('📝 Updating profile picture for:', uid);
    console.log('   New URL:', profilePictureUrl);

    const updates = {
      profilePicture: profilePictureUrl,
      updatedAt: new Date().toISOString(),
    };

    // Update in handymen collection
    await db.collection('handymen').doc(uid).update(updates);

    console.log('✅ Profile picture updated');
  } catch (error) {
    console.error('❌ Error updating profile picture:', error);
    throw error;
  }
}



}

module.exports = new UserService();

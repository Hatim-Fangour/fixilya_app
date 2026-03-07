const { AppError } = require("../../../../shared/utils/appError");
const admin = require("../../../../shared/config/firebase");
const logger = require("../../../../shared/utils/logger");
const {
  HANDYMAN_COLLECTION_NAME,
  USER_COLLECTION_NAME,
} = require("../../../../shared/config/appConstats");

const auth = admin.auth();
const db = admin.firestore();

class HandymanService {
  // ─────────────────────────────────────────────
  // NEARBY (public — map view)
  // ─────────────────────────────────────────────

  /**
   * Get approved, non-suspended handymen near a given location.
   *
   * Privacy rules:
   *   - 'exact'            → return stored lat/lon
   *   - 'city_only'        → return city-centre coords (geocoded server-side)
   *   - 'on_booking_accept'→ excluded from the map entirely
   *   - legacy null        → treated as 'exact' if coords exist
   *
   * @param {number} lat  - client latitude
   * @param {number} lon  - client longitude
   * @param {number} radiusKm - search radius in kilometres (default 50)
   * @returns {Array<Object>} handymen within radius, sorted by distance
   */
  async getNearbyHandymen(lat, lon, radiusKm = 50) {
    try {
      logger.info(`🗺️  [getNearbyHandymen] lat=${lat} lon=${lon} radius=${radiusKm}km`);

      const snapshot = await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .where("approved", "==", true)
        .where("suspended", "==", false)
        .get();

      const results = [];

      // Well-known Moroccan city centres for server-side geocoding fallback.
      // This avoids calling an external geocoding API on every request.
      const CITY_COORDS = {
        casablanca:  { lat: 33.5731, lon: -7.5898 },
        rabat:       { lat: 34.0209, lon: -6.8417 },
        marrakech:   { lat: 31.6295, lon: -7.9811 },
        fes:         { lat: 34.0331, lon: -5.0003 },
        fez:         { lat: 34.0331, lon: -5.0003 },
        tangier:     { lat: 35.7595, lon: -5.8340 },
        tanger:      { lat: 35.7595, lon: -5.8340 },
        agadir:      { lat: 30.4278, lon: -9.5981 },
        meknes:      { lat: 33.8935, lon: -5.5473 },
        oujda:       { lat: 34.6814, lon: -1.9086 },
        kenitra:     { lat: 34.2610, lon: -6.5802 },
        tetouan:     { lat: 35.5785, lon: -5.3684 },
        safi:        { lat: 32.2994, lon: -9.2372 },
        mohammedia:  { lat: 33.6866, lon: -7.3830 },
        eljadida:    { lat: 33.2316, lon: -8.5007 },
        "el jadida": { lat: 33.2316, lon: -8.5007 },
        beni_mellal: { lat: 32.3373, lon: -6.3498 },
        "beni mellal": { lat: 32.3373, lon: -6.3498 },
        nador:       { lat: 35.1688, lon: -2.9287 },
        taza:        { lat: 34.2100, lon: -4.0100 },
        settat:      { lat: 33.0011, lon: -7.6166 },
        khouribga:   { lat: 32.8811, lon: -6.9063 },
        salé:        { lat: 34.0531, lon: -6.7986 },
        sale:        { lat: 34.0531, lon: -6.7986 },
        temara:      { lat: 33.9275, lon: -6.9070 },
      };

      for (const doc of snapshot.docs) {
        const data = doc.data();

        const privacy = data.locationPrivacy || "city_only";

        // Never show handymen who chose to hide until booking acceptance
        if (privacy === "on_booking_accept") continue;

        let handymanLat, handymanLon;
        let isCityLevel = false;

        if (privacy === "city_only") {
          // Resolve city to coordinates using the lookup table
          const city = (data.city || "").trim().toLowerCase();
          if (!city) continue;

          const coords = CITY_COORDS[city] || CITY_COORDS[city.replace(/\s+/g, "_")];
          if (!coords) {
            logger.warn(`🗺️  Unknown city "${data.city}" for handyman ${doc.id} — skipping`);
            continue;
          }
          handymanLat = coords.lat;
          handymanLon = coords.lon;
          isCityLevel = true;
        } else {
          // 'exact' or legacy null — use stored coordinates
          if (data.latitude == null || data.longitude == null) continue;
          handymanLat = parseFloat(data.latitude);
          handymanLon = parseFloat(data.longitude);
          if (isNaN(handymanLat) || isNaN(handymanLon)) continue;
        }

        const distance = this._haversineKm(lat, lon, handymanLat, handymanLon);

        if (distance <= radiusKm) {
          // Determine primary category from skills array
          const category =
            Array.isArray(data.skills) && data.skills.length > 0
              ? data.skills[0]
              : "Service";

          results.push({
            id: doc.id,
            uid: doc.id,
            fullName: data.fullName || "Handyman",
            profilePicture: data.profilePicture || "",
            category,
            skills: data.skills || [],
            city: data.city || "",
            rating: data.rating || 0,
            totalReviews: data.totalReviews || 0,
            reviews: data.totalReviews || 0,
            completedJobs: data.completedJobs || 0,
            isAvailable: data.isAvailable ?? false,
            hourlyRate: data.hourlyRate || 0,
            bio: data.bio || "",
            phoneNumber: data.phone || "",
            showPhoneNumber: data.showPhoneNumber ?? false,
            latitude: handymanLat,
            longitude: handymanLon,
            distance: parseFloat(distance.toFixed(2)),
            isCityLevel,
          });
        }
      }

      // Sort by distance ascending
      results.sort((a, b) => a.distance - b.distance);

      logger.info(`✅ [getNearbyHandymen] Found ${results.length} handymen within ${radiusKm}km`);
      return results;
    } catch (error) {
      logger.error(`❌ [getNearbyHandymen] ${error.message}`);
      throw error;
    }
  }

  /**
   * Haversine formula: distance in km between two lat/lon points.
   */
  _haversineKm(lat1, lon1, lat2, lon2) {
    const R = 6371; // Earth radius in km
    const dLat = this._degToRad(lat2 - lat1);
    const dLon = this._degToRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(this._degToRad(lat1)) *
        Math.cos(this._degToRad(lat2)) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  _degToRad(deg) {
    return deg * (Math.PI / 180);
  }

  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────


  /**
 * Get all approved, non-suspended handymen.
 */
async getAllHandymen() {
  try {
    logger.info('🔍 Fetching all approved handymen');

    const snapshot = await db
      .collection(HANDYMAN_COLLECTION_NAME)
      .where('approved', '==', true)
      .where('suspended', '==', false)
      .get();

    const handymen = snapshot.docs.map((doc) => {
      const data = doc.data();
      return data
      // return {
      //   uid:            doc.id,
      //   name:           data.fullName   || '',
      //   profilePicture: data.profilePicture || '',
      //   skills:         data.skills     || [],
      //   city:           data.city       || '',
      //   rating:         data.rating     || 0,
      //   totalReviews:   data.totalReviews || 0,
      //   completedJobs:  data.completedJobs || 0,
      //   isAvailable:    data.isAvailable ?? false,
      //   hourlyRate:     data.hourlyRate  || 0,
      //   bio:            data.bio         || '',
      // };
    });

    logger.info(`✅ Returned ${handymen.length} handymen`);
    return handymen;
  } catch (error) {
    logger.error(`❌ Error fetching all handymen: ${error.message}`);
    throw error;
  }
}


  /**
   * Get the full handyman profile (merges handymen + users collections).
   */
  async getHandymanProfile(uid) {
    try {
      logger.info(`🔍 Fetching handyman profile: ${uid}`);

      const handymanDoc = await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .doc(uid)
        .get();

      if (!handymanDoc.exists) {
        throw new AppError("Handyman profile not found", 404);
      }

      const handymanData = handymanDoc.data();

      // Merge with user record for email / phone fallback
      const userDoc = await db
        .collection(USER_COLLECTION_NAME)
        .doc(uid)
        .get();
      const userData = userDoc.exists ? userDoc.data() : {};

      const profile = {
        ...handymanData,
        fullName: userData.fullName || handymanData.fullName || "Handyman",
        email: userData.email || "",
        phone: userData.phone || handymanData.phone || "",
        uid,
      };

      logger.info(`✅ Handyman profile loaded for: ${uid}`);
      return profile;
    } catch (error) {
      logger.error(`❌ Error fetching handyman profile: ${error.message}`);
      throw error;
    }
  }

  /**
   * Update the handyman profile.
   * Protected fields are stripped automatically.
   */
  async updateHandymanProfile(uid, updates) {
    try {
      logger.info(`📝 Updating handyman profile: ${uid}`);

      // Strip fields that should never be updated via this endpoint
      const protectedFields = [
        "uid",
        "email",
        "createdAt",
        "approved",
        "suspended",
        "rejected",
        "reviewStatus",
        "rating",
        "totalReviews",
        "completedJobs",
      ];
      protectedFields.forEach((field) => delete updates[field]);

      updates.updatedAt = new Date().toISOString();

      await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .doc(uid)
        .update(updates);

      // Mirror name / phone changes into the users collection
      const userUpdates = {};
      if (updates.fullName) userUpdates.fullName = updates.fullName;
      if (updates.phone) userUpdates.phone = updates.phone;

      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = new Date().toISOString();
        await db.collection(USER_COLLECTION_NAME).doc(uid).update(userUpdates);
      }

      logger.info(`✅ Handyman profile updated: ${uid}`);

      return {
        success: true,
        message: "Profile updated successfully",
      };
    } catch (error) {
      logger.error(`❌ Error updating handyman profile: ${error.message}`);
      throw error;
    }
  }

  /**
   * Update only the profile picture URL.
   */
  async updateProfilePicture(uid, profilePictureUrl) {
    try {
      logger.info(`📸 Updating profile picture for: ${uid}`);

      await db.collection(HANDYMAN_COLLECTION_NAME).doc(uid).update({
        profilePicture: profilePictureUrl,
        updatedAt: new Date().toISOString(),
      });

      logger.info(`✅ Profile picture updated for: ${uid}`);

      return {
        success: true,
        message: "Profile picture updated successfully",
        data: { profilePicture: profilePictureUrl },
      };
    } catch (error) {
      logger.error(`❌ Error updating profile picture: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // AVAILABILITY
  // ─────────────────────────────────────────────

  /**
   * Toggle handyman availability on / off.
   */
  async updateAvailabilityStatus(uid, isAvailable) {
    try {
      logger.info(`🔄 Updating availability for ${uid}: ${isAvailable}`);

      await db.collection(HANDYMAN_COLLECTION_NAME).doc(uid).update({
        isAvailable,
        lastAvailabilityUpdate: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      logger.info(`✅ Availability updated for: ${uid}`);

      return {
        success: true,
        message: "Availability updated successfully",
        data: { isAvailable },
      };
    } catch (error) {
      logger.error(`❌ Error updating availability: ${error.message}`);
      throw error;
    }
  }

  /**
   * Get current availability status.
   */
  async getAvailabilityStatus(uid) {
    try {
      const doc = await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .doc(uid)
        .get();

      if (!doc.exists) {
        return { isAvailable: false };
      }

      const data = doc.data();
      return {
        isAvailable: data.isAvailable ?? false,
        lastUpdate: data.lastAvailabilityUpdate ?? null,
      };
    } catch (error) {
      logger.error(`❌ Error getting availability: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // STATS & RATINGS
  // ─────────────────────────────────────────────

  /**
   * Calculate bookings + earnings + rating stats for the dashboard.
   */
  async getHandymanStats(uid) {
    try {
      logger.info(`📊 Fetching stats for handyman: ${uid}`);

      const handymanDoc = await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .doc(uid)
        .get();

      if (!handymanDoc.exists) {
        throw new AppError("Handyman not found", 404);
      }

      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const weekAgo = new Date(today);
      weekAgo.setDate(weekAgo.getDate() - 7);
      const monthAgo = new Date(today);
      monthAgo.setMonth(monthAgo.getMonth() - 1);

      // ── Bookings ──────────────────────────────
      const bookingsSnapshot = await db
        .collection("bookings")
        .where("handymanId", "==", uid)
        .get();

      let todayEarnings = 0;
      let weeklyEarnings = 0;
      let monthlyEarnings = 0;
      let activeBookings = 0;
      let completedJobs = 0;
      let pendingRequests = 0;

      bookingsSnapshot.forEach((doc) => {
        const data = doc.data();
        const status = data.status || "";
        const amount = parseFloat(data.amount ?? data.estimatedPrice ?? 0);

        switch (status) {
          case "pending":
            pendingRequests++;
            activeBookings++;
            break;

          case "confirmed":
          case "in_progress":
            activeBookings++;
            break;

          case "completed":
            completedJobs++;

            if (data.completedAt && amount > 0) {
              const completedAt = data.completedAt.toDate
                ? data.completedAt.toDate()
                : new Date(data.completedAt);

              const completedDate = new Date(
                completedAt.getFullYear(),
                completedAt.getMonth(),
                completedAt.getDate()
              );

              if (completedDate >= today) todayEarnings += amount;
              if (completedDate >= weekAgo) weeklyEarnings += amount;
              if (completedDate >= monthAgo) monthlyEarnings += amount;
            }
            break;
        }
      });

      // ── Reviews ───────────────────────────────
      const { rating, reviewCount: totalReviews } =
        await this.getRatingStats(uid);

      const stats = {
        todayEarnings,
        weeklyEarnings,
        monthlyEarnings,
        activeBookings,
        completedJobs,
        pendingRequests,
        rating,
        totalReviews,
      };

      logger.info(`✅ Stats calculated for ${uid}: ${JSON.stringify(stats)}`);
      return stats;
    } catch (error) {
      logger.error(`❌ Error fetching handyman stats: ${error.message}`);
      throw error;
    }
  }

  /**
   * Calculate average rating from reviews collection.
   */
  async getRatingStats(uid) {
    try {
      logger.info(`⭐ Fetching rating stats for: ${uid}`);

      const reviewsSnapshot = await db
        .collection("reviews")
        .where("handymanId", "==", uid)
        .get();

      if (reviewsSnapshot.empty) {
        return { rating: 0.0, reviewCount: 0 };
      }

      let totalRating = 0;
      const reviewCount = reviewsSnapshot.size;

      reviewsSnapshot.forEach((doc) => {
        totalRating += doc.data().rating ?? 0;
      });

      const rating = parseFloat((totalRating / reviewCount).toFixed(1));

      logger.info(`✅ Rating stats for ${uid}: ${rating} (${reviewCount} reviews)`);
      return { rating, reviewCount };
    } catch (error) {
      logger.error(`❌ Error fetching rating stats: ${error.message}`);
      // Return safe defaults — don't crash the whole stats call
      return { rating: 0.0, reviewCount: 0 };
    }
  }

  // ─────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────

  /**
   * Get notification preferences and basic account info.
   */
  async getHandymanSettings(uid) {
    try {
      logger.info(`⚙️  Fetching settings for handyman: ${uid}`);

      const [handymanDoc, userDoc] = await Promise.all([
        db.collection(HANDYMAN_COLLECTION_NAME).doc(uid).get(),
        db.collection(USER_COLLECTION_NAME).doc(uid).get(),
      ]);

      if (!handymanDoc.exists) {
        throw new AppError("Handyman profile not found", 404);
      }

      const handymanData = handymanDoc.data();
      const userData = userDoc.exists ? userDoc.data() : {};

      return {
        fullName: handymanData.fullName || userData.fullName || "",
        email: userData.email || handymanData.email || "",
        phone: handymanData.phone || userData.phone || "",
        city: handymanData.city || "",
        experience: handymanData.experience || "",
        bio: handymanData.bio || "",
        profilePicture: handymanData.profilePicture || "",
        pushNotifications: handymanData.pushNotifications ?? true,
        emailNotifications: handymanData.emailNotifications ?? false,
        smsNotifications: handymanData.smsNotifications ?? true,
        showPhoneNumber: handymanData.showPhoneNumber ?? false,
      };
    } catch (error) {
      logger.error(`❌ Error fetching handyman settings: ${error.message}`);
      throw error;
    }
  }

  /**
   * Update notification preferences only (whitelist-based).
   */
  async updateHandymanSettings(uid, updates) {
    try {
      logger.info(`⚙️  Updating settings for handyman: ${uid}`);

      const allowedFields = [
        "pushNotifications",
        "emailNotifications",
        "smsNotifications",
        "showPhoneNumber",
      ];

      const filteredUpdates = Object.fromEntries(
        Object.entries(updates).filter(([key]) => allowedFields.includes(key))
      );

      if (Object.keys(filteredUpdates).length === 0) {
        logger.warn(`⚠️  No valid settings fields provided for: ${uid}`);
        return { success: true, message: "No changes applied" };
      }

      filteredUpdates.updatedAt = new Date().toISOString();

      await db
        .collection(HANDYMAN_COLLECTION_NAME)
        .doc(uid)
        .update(filteredUpdates);

      logger.info(`✅ Settings updated for: ${uid}`);

      return {
        success: true,
        message: "Settings updated successfully",
        phoneRevealed: filteredUpdates.showPhoneNumber === true,
      };
    } catch (error) {
      logger.error(`❌ Error updating handyman settings: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // PHONE REVEAL NOTIFICATION
  // ─────────────────────────────────────────────

  /**
   * Notify all clients who have a confirmed/in_progress booking with this
   * handyman that the handyman has revealed their phone number.
   * Fires-and-forgets FCM push + stores an in-app notification doc.
   */
  async notifyClientsPhoneRevealed(handymanUid) {
    try {
      const handymanDoc = await db.collection(HANDYMAN_COLLECTION_NAME).doc(handymanUid).get();
      if (!handymanDoc.exists) return;

      const { fullName = "Your handyman", phone = "" } = handymanDoc.data();

      const bookingsSnap = await db
        .collection("bookings")
        .where("handymanId", "==", handymanUid)
        .where("status", "in", ["confirmed", "in_progress"])
        .get();

      if (bookingsSnap.empty) return;

      const clientIds = [...new Set(
        bookingsSnap.docs.map((d) => d.data().clientId).filter(Boolean)
      )];

      await Promise.allSettled(
        clientIds.map(async (clientId) => {
          try {
            const userDoc = await db.collection(USER_COLLECTION_NAME).doc(clientId).get();
            if (!userDoc.exists) return;

            const { fcmToken } = userDoc.data();

            // Store in-app notification
            await db.collection("notifications").add({
              userId: clientId,
              type: "handyman_phone_revealed",
              title: "Phone Number Available",
              body: `${fullName} has shared their phone number with you`,
              data: { handymanId: handymanUid, phone },
              read: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Send FCM push if token is present
            if (fcmToken) {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: "📞 Phone Number Available",
                  body: `${fullName} has shared their phone number with you`,
                },
                data: { type: "handyman_phone_revealed", handymanId: handymanUid, phone },
                android: { priority: "high" },
              });
            }
          } catch (err) {
            logger.warn(`[notifyClientsPhoneRevealed] client ${clientId}: ${err.message}`);
          }
        })
      );

      logger.info(`✅ Phone reveal notifications sent to ${clientIds.length} clients for ${handymanUid}`);
    } catch (error) {
      logger.error(`❌ [notifyClientsPhoneRevealed] ${error.message}`);
      // Don't throw — notification failure must never fail the settings update
    }
  }
}

module.exports = new HandymanService();
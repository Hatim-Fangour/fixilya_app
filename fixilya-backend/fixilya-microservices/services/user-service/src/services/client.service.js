const { AppError } = require("../../../../shared/utils/appError");
const admin = require("../../../../shared/config/firebase");
const logger = require("../../../../shared/utils/logger");
const {
  HANDYMAN_COLLECTION_NAME,
  CLIENT_COLLECTION_NAME,
  USER_COLLECTION_NAME,
} = require("../../../../shared/config/appConstats");

const db = admin.firestore();

// Booking collection name — must match booking-service
const BOOKINGS_COLLECTION = "bookings";

// Convert a Firestore Timestamp (or null) to an ISO-8601 string.
// Without this, Express serialises Timestamps as {_seconds,_nanoseconds}
// which Flutter's DateTime.parse() cannot handle.
const _ts = (v) => v?.toDate?.()?.toISOString?.() ?? null;

class ClientService {
  // ─────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────

  async getProfile(uid) {
    try {
      const [userDoc, clientDoc] = await Promise.all([
        db.collection(USER_COLLECTION_NAME).doc(uid).get(),
        db.collection(CLIENT_COLLECTION_NAME).doc(uid).get(),
      ]);

      if (!clientDoc.exists) {
        throw new AppError("Client profile not found", 404);
      }

      return {
        ...userDoc.data(),
        ...clientDoc.data(),
        uid,
      };
    } catch (error) {
      logger.error(`❌ [ClientService.getProfile] uid=${uid}: ${error.message}`);
      throw error;
    }
  }

  async updateProfile(uid, updates) {
    try {
      // Strip immutable fields
      const immutable = ["uid", "email", "userType", "createdAt", "approved", "suspended"];
      immutable.forEach((f) => delete updates[f]);

      updates.updatedAt = new Date().toISOString();

      await db.collection(CLIENT_COLLECTION_NAME).doc(uid).update(updates);

      // Mirror name / phone into users collection
      const userUpdates = {};
      if (updates.fullName) userUpdates.fullName = updates.fullName;
      if (updates.phone)    userUpdates.phone    = updates.phone;

      if (Object.keys(userUpdates).length > 0) {
        userUpdates.updatedAt = new Date().toISOString();
        await db.collection(USER_COLLECTION_NAME).doc(uid).update(userUpdates);
      }

      return { success: true, message: "Profile updated successfully" };
    } catch (error) {
      logger.error(`❌ [ClientService.updateProfile] uid=${uid}: ${error.message}`);
      throw error;
    }
  }

  // ─────────────────────────────────────────────
  // STATS
  // ─────────────────────────────────────────────

  async getStats(uid) {
    try {
      const [bookingsSnap, clientDoc] = await Promise.all([
        db.collection(BOOKINGS_COLLECTION)
          .where("clientId", "==", uid)
          .count()
          .get(),
        db.collection(CLIENT_COLLECTION_NAME).doc(uid).get(),
      ]);

      const totalBookings = bookingsSnap.data().count;
      const clientData    = clientDoc.exists ? clientDoc.data() : {};
      const favoritesCount = (clientData.favoriteHandymen || []).length;

      return { totalBookings, favoritesCount };
    } catch (error) {
      logger.error(`❌ [ClientService.getStats] uid=${uid}: ${error.message}`);
      // Fallback — don't crash the profile load
      return { totalBookings: 0, favoritesCount: 0 };
    }
  }

  // ─────────────────────────────────────────────
  // BOOKINGS  (recent snapshot — not SSE)
  // ─────────────────────────────────────────────

  async getBookings(uid, { limit = 5, status } = {}) {
    try {
      let query = db
        .collection(BOOKINGS_COLLECTION)
        .where("clientId", "==", uid)
        .orderBy("createdAt", "desc")
        .limit(limit);

      if (status && status !== "all") {
        query = query.where("status", "==", status);
      }

      const snap = await query.get();

      return snap.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          ...data,
          // Convert every Firestore Timestamp to ISO-8601 string so Flutter can parse them.
          // Raw Timestamp objects serialize as {_seconds,_nanoseconds} which Flutter cannot parse.
          createdAt:   _ts(data.createdAt),
          updatedAt:   _ts(data.updatedAt),
          scheduledAt: _ts(data.scheduledAt),
          acceptedAt:  _ts(data.acceptedAt),
          declinedAt:  _ts(data.declinedAt),
          startedAt:   _ts(data.startedAt),
          completedAt: _ts(data.completedAt),
          cancelledAt: _ts(data.cancelledAt),
        };
      });
    } catch (error) {
      logger.error(`❌ [ClientService.getBookings] uid=${uid}: ${error.message}`);
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // FAVORITES  (handyman IDs stored on client doc)
  // ─────────────────────────────────────────────

  async getFavorites(uid) {
    try {
      const clientDoc = await db.collection(CLIENT_COLLECTION_NAME).doc(uid).get();
      if (!clientDoc.exists) return [];

      const favoriteIds = clientDoc.data().favoriteHandymen || [];
      if (favoriteIds.length === 0) return [];

      // Fetch each handyman profile in parallel (cap at 20)
      const ids = favoriteIds.slice(0, 20);
      const docs = await Promise.all(
        ids.map((id) => db.collection(HANDYMAN_COLLECTION_NAME).doc(id).get())
      );

      return docs
        .filter((d) => d.exists)
        .map((d) => ({ id: d.id, ...d.data() }));
    } catch (error) {
      logger.error(`❌ [ClientService.getFavorites] uid=${uid}: ${error.message}`);
      return [];
    }
  }

  async addFavorite(uid, handymanId) {
    try {
      await db.collection(CLIENT_COLLECTION_NAME).doc(uid).update({
        favoriteHandymen: admin.firestore.FieldValue.arrayUnion(handymanId),
        updatedAt: new Date().toISOString(),
      });
      return { success: true, message: "Added to favourites" };
    } catch (error) {
      logger.error(`❌ [ClientService.addFavorite]: ${error.message}`);
      throw error;
    }
  }

  async removeFavorite(uid, handymanId) {
    try {
      await db.collection(CLIENT_COLLECTION_NAME).doc(uid).update({
        favoriteHandymen: admin.firestore.FieldValue.arrayRemove(handymanId),
        updatedAt: new Date().toISOString(),
      });
      return { success: true, message: "Removed from favourites" };
    } catch (error) {
      logger.error(`❌ [ClientService.removeFavorite]: ${error.message}`);
      throw error;
    }
  }
}

module.exports = new ClientService();
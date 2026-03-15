import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/data/models/handyman_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// HandymanController
/// Manages handyman listing, detail fetching, and profile operations.
class HandymanController extends GetxController {
  // ─── Services ────────────────────────────────────────────────────────────
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ─── State ───────────────────────────────────────────────────────────────
  final nearbyHandymen = <HandymanModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = ''.obs;
  final currentHandymanProfile = Rx<HandymanModel?>(null);

  // ─── Computed ────────────────────────────────────────────────────────────
  String? get _currentUid => _auth.currentUser?.uid;

  // ─── Lifecycle ───────────────────────────────────────────────────────────
  @override
  void onInit() {
    super.onInit();
    fetchNearbyHandymen();
  }

  // ─── Fetch nearby handymen ───────────────────────────────────────────────
  Future<void> fetchNearbyHandymen({String? category, String? city}) async {
    isLoading.value = true;
    errorMessage.value = '';

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('handymen')
          .where('verified', isEqualTo: true);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      if (city != null && city.isNotEmpty) {
        query = query.where('city', isEqualTo: city);
      }

      final snapshot = await query.limit(50).get();

      nearbyHandymen.value = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return HandymanModel.fromJson(data);
      }).toList();

      // Sort by rating descending
      nearbyHandymen.sort((a, b) => b.rating.compareTo(a.rating));

      if (kDebugMode) {
        debugPrint(
          'HandymanController: fetched ${nearbyHandymen.length} handymen',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HandymanController: fetchNearbyHandymen error: $e');
      }
      errorMessage.value = 'Failed to load handymen';
      Get.snackbar(
        'Error',
        'Failed to load handymen. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Get handyman details ────────────────────────────────────────────────
  Future<HandymanModel?> getHandymanDetails(String handymanId) async {
    try {
      final doc =
          await _firestore.collection('handymen').doc(handymanId).get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      final data = doc.data()!;
      data['id'] = doc.id;
      return HandymanModel.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HandymanController: getHandymanDetails error: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to load handyman details.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return null;
    }
  }

  // ─── Update handyman profile (for handyman users) ────────────────────────
  Future<bool> updateProfile(Map<String, dynamic> profileData) async {
    final uid = _currentUid;
    if (uid == null) {
      Get.snackbar(
        'Error',
        'You must be logged in to update your profile.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    }

    isLoading.value = true;

    try {
      await _firestore.collection('handymen').doc(uid).update({
        ...profileData,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh the current profile
      final updated = await getHandymanDetails(uid);
      if (updated != null) {
        currentHandymanProfile.value = updated;
      }

      Get.snackbar(
        'Success',
        'Profile updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle, color: Colors.white),
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('HandymanController: updateProfile error: $e');
      }
      Get.snackbar(
        'Error',
        'Failed to update profile. Please try again.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // ─── Load current user's handyman profile ────────────────────────────────
  Future<void> loadCurrentHandymanProfile() async {
    final uid = _currentUid;
    if (uid == null) return;

    final profile = await getHandymanDetails(uid);
    currentHandymanProfile.value = profile;
  }
}

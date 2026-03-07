import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class FirebaseImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Save profile image URL to Firestore
  Future<bool> saveProfileImageUrl({
    required String userId,
    required String imageUrl,
    required String userType,
  }) async {
    try {
      await _firestore.collection(userType).doc(userId).set({
        'profileImage': imageUrl,
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) debugPrint('✅ Profile image URL saved to Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving profile image URL: $e');
      return false;
    }
  }

  // ✅ Save work images URLs to Firestore
  Future<bool> saveWorkImages({
    required String userId,
    required List<String> imageUrls,
    required String userType,
  }) async {
    try {
      // Get existing work images
      final doc = await _firestore.collection(userType).doc(userId).get();
      final data = doc.data();
      List<String> existingImages = [];

      if (data != null && data['workImages'] != null) {
        existingImages = List<String>.from(data['workImages']);
      }

      // Add new images
      existingImages.addAll(imageUrls);

      // Save to Firestore
      await _firestore.collection(userType).doc(userId).update({
        'workImages': existingImages,
        'workImagesUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Work images URLs saved to Firestore');
      if (kDebugMode) debugPrint('   Total images: ${existingImages.length}');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving work images URLs: $e');
      return false;
    }
  }

  // ✅ Add single work image
  Future<bool> addWorkImage({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workImages': FieldValue.arrayUnion([imageUrl]),
        'workImagesUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Work image URL added to Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error adding work image URL: $e');
      return false;
    }
  }

  // ✅ Remove work image
  Future<bool> removeWorkImage({
    required String userId,
    required String imageUrl,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workImages': FieldValue.arrayRemove([imageUrl]),
        'workImagesUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Work image URL removed from Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error removing work image URL: $e');
      return false;
    }
  }

  // ✅ Get profile image URL
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();

      if (data != null && data['profileImage'] != null) {
        return data['profileImage'] as String;
      }

      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting profile image URL: $e');
      return null;
    }
  }

  // ✅ Get work images URLs
  Future<List<String>> getWorkImages(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();

      if (data != null && data['workImages'] != null) {
        return List<String>.from(data['workImages']);
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting work images URLs: $e');
      return [];
    }
  }

  // ✅ Delete profile image URL
  Future<bool> deleteProfileImageUrl(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'profileImage': FieldValue.delete(),
        'profileImageUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Profile image URL deleted from Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting profile image URL: $e');
      return false;
    }
  }

  // ✅ Clear all work images
  Future<bool> clearWorkImages(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'workImages': [],
        'workImagesUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ All work images URLs cleared from Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error clearing work images URLs: $e');
      return false;
    }
  }

  // ✅ Save portfolio item with image
  Future<String?> savePortfolioItem({
    required String userId,
    required String title,
    required String client,
    required String imageUrl,
    String? description,
  }) async {
    try {
      final portfolioRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .doc();

      await portfolioRef.set({
        'title': title,
        'client': client,
        'imageUrl': imageUrl,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Portfolio item saved with image URL');
      return portfolioRef.id;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving portfolio item: $e');
      return null;
    }
  }

  // ✅ Get portfolio items
  Future<List<Map<String, dynamic>>> getPortfolioItems(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting portfolio items: $e');
      return [];
    }
  }

  // ✅ Delete portfolio item
  Future<bool> deletePortfolioItem({
    required String userId,
    required String portfolioId,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('portfolio')
          .doc(portfolioId)
          .delete();

      if (kDebugMode) debugPrint('✅ Portfolio item deleted');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error deleting portfolio item: $e');
      return false;
    }
  }
}

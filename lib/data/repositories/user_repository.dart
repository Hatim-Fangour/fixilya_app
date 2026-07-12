import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'users';

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Get user stream
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(_collection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Create user
  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection(_collection)
        .doc(user.id)
        .set(user.toFirestore());
  }

  // Update user
  Future<void> updateUser(UserModel user) async {
    await _firestore
        .collection(_collection)
        .doc(user.id)
        .update(user.toFirestore());
  }

  // Update specific fields
  Future<void> updateUserFields(
    String userId,
    Map<String, dynamic> fields,
  ) async {
    fields['updatedAt'] = DateTime.now().toIso8601String();
    await _firestore.collection(_collection).doc(userId).update(fields);
  }

  // Delete user
  Future<void> deleteUser(String userId) async {
    await _firestore.collection(_collection).doc(userId).delete();
  }

  // Get users by type
  Future<List<UserModel>> getUsersByType(UserType userType) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('userType', isEqualTo: userType.name)
        .limit(200)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // Search users
  Future<List<UserModel>> searchUsers(String query) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('fullName', isGreaterThanOrEqualTo: query)
        .where('fullName', isLessThan: '${query}z')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }
}

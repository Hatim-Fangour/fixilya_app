import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Calculate profile completion percentage
  Future<int> calculateProfileCompletion({
    required String userId,
    required String userType,
  }) async {
    try {
      if (userType == 'handyman') {
        return await _calculateHandymanCompletion(userId);
      } else {
        return await _calculateClientCompletion(userId);
      }
    } catch (e) {
      print('Error calculating completion: $e');
      return 0;
    }
  }

  Future<int> _calculateHandymanCompletion(String userId) async {
    final doc = await _firestore.collection('handymen').doc(userId).get();
    if (!doc.exists) return 0;

    final data = doc.data()!;
    int completed = 0;
    int total = 10;

    // Basic info (40%)
    if (data['city']?.toString().isNotEmpty ?? false) completed++;
    if (data['experience']?.toString().isNotEmpty ?? false) completed++;
    if ((data['hourlyRate'] ?? 0) > 0) completed++;
    if (data['bio']?.toString().isNotEmpty ?? false) completed++;

    // Skills (20%)
    if ((data['skills'] as List?)?.isNotEmpty ?? false) {
      completed++;
      if ((data['skills'] as List).length >= 3) completed++;
    }

    // Profile picture (20%)
    if (data['profilePicture']?.toString().isNotEmpty ?? false) {
      completed++;
      completed++; // Extra weight for profile picture
    }

    // Work images (20%)
    if ((data['workImages'] as List?)?.isNotEmpty ?? false) {
      completed++;
      if ((data['workImages'] as List).length >= 3) completed++;
    }

    return ((completed / total) * 100).round();
  }

  Future<int> _calculateClientCompletion(String userId) async {
    final doc = await _firestore.collection('clients').doc(userId).get();
    if (!doc.exists) return 0;

    final data = doc.data()!;
    int completed = 0;
    int total = 4;

    // City (25%)
    if (data['city']?.toString().isNotEmpty ?? false) completed++;

    // Address (25%)
    if (data['address']?.toString().isNotEmpty ?? false) completed++;

    // Profile picture (50%)
    if (data['profilePicture']?.toString().isNotEmpty ?? false) {
      completed++;
      completed++; // Extra weight for profile picture
    }

    return ((completed / total) * 100).round();
  }

  // Get profile completion details
  Future<Map<String, dynamic>> getProfileCompletionDetails({
    required String userId,
    required String userType,
  }) async {
    try {
      final collection = userType == 'handyman' ? 'handymen' : 'clients';
      final doc = await _firestore.collection(collection).doc(userId).get();

      if (!doc.exists) {
        return {'percentage': 0, 'missingFields': []};
      }

      final data = doc.data()!;
      List<String> missingFields = [];

      if (userType == 'handyman') {
        if (data['city']?.toString().isEmpty ?? true) missingFields.add('City');
        if (data['experience']?.toString().isEmpty ?? true) {
          missingFields.add('Experience');
        }
        if ((data['hourlyRate'] ?? 0) == 0) missingFields.add('Hourly Rate');
        if (data['bio']?.toString().isEmpty ?? true) missingFields.add('Bio');
        if ((data['skills'] as List?)?.isEmpty ?? true) {
          missingFields.add('Skills');
        }
        if (data['profilePicture']?.toString().isEmpty ?? true) {
          missingFields.add('Profile Picture');
        }
        if ((data['workImages'] as List?)?.isEmpty ?? true) {
          missingFields.add('Work Photos');
        }
      } else {
        if (data['city']?.toString().isEmpty ?? true) missingFields.add('City');
        if (data['address']?.toString().isEmpty ?? true) {
          missingFields.add('Address');
        }
        if (data['profilePicture']?.toString().isEmpty ?? true) {
          missingFields.add('Profile Picture');
        }
      }

      final percentage = await calculateProfileCompletion(
        userId: userId,
        userType: userType,
      );

      return {'percentage': percentage, 'missingFields': missingFields};
    } catch (e) {
      print('Error getting completion details: $e');
      return {'percentage': 0, 'missingFields': []};
    }
  }
}

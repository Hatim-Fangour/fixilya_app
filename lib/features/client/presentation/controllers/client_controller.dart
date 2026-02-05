import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/client_data_service.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';

/// ClientProfileController
/// Handles all business logic, state management, and data operations
/// for the Client Profile Page
class ClientProfileController extends GetxController {
  // ============================================
  // SERVICES
  // ============================================
  final _clientDataService = ClientDataService();
  final _authService = AuthService();

  // ============================================
  // STATE
  // ============================================
  final isEditing = false.obs;
  final isLoadingData = true.obs;
  final profileCompletion = 0.obs;

  // Profile Data
  final name = 'Client'.obs;
  final email = ''.obs;
  final phone = ''.obs;
  final address = ''.obs;
  final city = ''.obs;
  final profilePicture = ''.obs;
  final memberSince = Rx<DateTime?>(null);

  // Stats
  final totalBookings = 0.obs;
  final completedBookings = 0.obs;
  final activeBookings = 0.obs;
  final favoriteHandymen = 0.obs;

  // Data Lists
  final recentBookings = <Map<String, dynamic>>[].obs;
  final favoriteServices = <Map<String, dynamic>>[].obs;

  // Raw Data
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;

  // Form Key
  final formKey = GlobalKey<FormState>();

  // ============================================
  // LIFECYCLE
  // ============================================
  @override
  void onInit() {
    super.onInit();
    loadProfileData();
  }

  // ============================================
  // DATA LOADING
  // ============================================

  /// Load all profile data from Firebase
  Future<void> loadProfileData() async {
    isLoadingData.value = true;

    try {
      // Load profile and stats in parallel
      final results = await Future.wait([
        _clientDataService.getClientProfile(),
        _clientDataService.getClientStats(),
      ]);

      _profileData = results[0];
      _statsData = results[1];

      print('📊 Profile Data: $_profileData');
      print('📊 Stats Data: $_statsData');

      if (_profileData != null) {
        // Map profile data
        name.value = _profileData!['fullName'] ?? 'Client';
        email.value = _profileData!['email'] ?? '';
        phone.value = _profileData!['phone'] ?? '';
        city.value = _profileData!['city'] ?? '';
        address.value = _profileData!['address'] ?? '';
        profilePicture.value = _profileData!['profilePicture'] ?? '';

        // Parse memberSince
        if (_profileData!['createdAt'] != null) {
          if (_profileData!['createdAt'] is Timestamp) {
            memberSince.value = (_profileData!['createdAt'] as Timestamp)
                .toDate();
          }
        }

        // Map stats data
        totalBookings.value = _statsData?['totalBookings'] ?? 0;
        completedBookings.value = _statsData?['completedBookings'] ?? 0;
        activeBookings.value = _statsData?['activeBookings'] ?? 0;
        favoriteHandymen.value = _statsData?['favoritesCount'] ?? 0;

        // Calculate profile completion
        profileCompletion.value = calculateProfileCompletion();

        print('✅ Client profile loaded successfully');
        print('   Name: ${name.value}');
        print('   Total Bookings: ${totalBookings.value}');
        print('   Favorites: ${favoriteHandymen.value}');
        print('   Profile Completion: ${profileCompletion.value}%');

        // Load additional data
        await Future.wait([loadRecentBookings(), loadFavoriteServices()]);
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
    } finally {
      isLoadingData.value = false;
    }
  }

  /// Load recent bookings
  Future<void> loadRecentBookings() async {
    try {
      final bookings = await _clientDataService.getClientBookings();

      recentBookings.value = bookings.take(5).map((booking) {
        return {
          'id': booking['id'],
          'handymanName': booking['handymanName'] ?? 'Unknown Handyman',
          'service': booking['service'] ?? 'Service',
          'date': formatDate(booking['createdAt']),
          'status': booking['status'] ?? 'pending',
          'price': '${booking['amount'] ?? 0} DH',
          'rating': booking['rating']?.toDouble(),
        };
      }).toList();

      print('✅ Loaded ${recentBookings.length} recent bookings');
    } catch (e) {
      print('❌ Error loading bookings: $e');
    }
  }

  /// Load favorite services
  Future<void> loadFavoriteServices() async {
    try {
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(_profileData?['uid'])
          .get();

      if (clientDoc.exists) {
        final favoriteServiceNames = List<String>.from(
          clientDoc.data()?['favoriteServices'] ?? [],
        );

        favoriteServices.value = favoriteServiceNames.map((serviceName) {
          return {'name': serviceName, 'icon': getServiceIcon(serviceName)};
        }).toList();

        print('✅ Loaded ${favoriteServices.length} favorite services');
      }
    } catch (e) {
      print('❌ Error loading favorite services: $e');
    }
  }

  // ============================================
  // CALCULATIONS
  // ============================================

  /// Calculate profile completion percentage
  int calculateProfileCompletion() {
    if (_profileData == null) return 0;

    int completedFields = 0;
    int totalFields = 6;

    // Full Name (20%)
    if (name.value.isNotEmpty && name.value != 'Client') completedFields++;

    // Phone (15%)
    if (phone.value.isNotEmpty) completedFields++;

    // City (15%)
    if (city.value.isNotEmpty) completedFields++;

    // Address (15%)
    if (address.value.isNotEmpty) completedFields++;

    // Profile picture (35% - double weight)
    if (profilePicture.value.isNotEmpty) {
      completedFields++;
      completedFields++; // Extra weight
    }

    return (completedFields / totalFields * 100).round();
  }

  // ============================================
  // ACTIONS
  // ============================================

  /// Toggle edit mode
  void toggleEditMode() {
    if (isEditing.value && formKey.currentState!.validate()) {
      formKey.currentState!.save();
      saveProfileToFirebase();
    }
    isEditing.value = !isEditing.value;
  }

  /// Save profile to Firebase
  Future<void> saveProfileToFirebase() async {
    try {
      print('💾 Saving client profile to Firebase...');

      final success = await _clientDataService.updateClientProfile({
        'fullName': name.value,
        'email': email.value,
        'phone': phone.value,
        'city': city.value,
        'address': address.value,
      });

      if (success) {
        print('✅ Client profile saved successfully');

        Get.snackbar(
          'Success',
          'Profile updated successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        throw Exception('Update returned false');
      }
    } catch (e) {
      print('❌ Error saving profile: $e');

      Get.snackbar(
        'Error',
        'Failed to update profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      // Show loading
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Logging out...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Sign out
      await _authService.signOut();

      // Close loading
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Navigate to welcome
      AppRoutes.toWelcome();

      // Success message
      Get.snackbar(
        'Success',
        'You have been logged out successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        icon: Icon(Icons.check_circle, color: Colors.white),
      );
    } catch (e) {
      print('❌ Logout error: $e');

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Logout failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Get service icon
  IconData getServiceIcon(String serviceName) {
    final iconMap = {
      'Plumbing': FontAwesomeIcons.faucet,
      'Electrical Work': FontAwesomeIcons.bolt,
      'Carpentry': FontAwesomeIcons.hammer,
      'Painting': FontAwesomeIcons.paintRoller,
      'Cleaning': FontAwesomeIcons.broom,
      'Gardening': FontAwesomeIcons.seedling,
      'AC Repair': FontAwesomeIcons.snowflake,
      'Appliance Repair': FontAwesomeIcons.plug,
    };

    return iconMap[serviceName] ?? FontAwesomeIcons.wrench;
  }

  /// Format date
  String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recent';
      }

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Recent';
    }
  }

  /// Format member since
  String formatMemberSince() {
    if (memberSince.value == null) return 'Member since Jan 2024';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return 'Member since ${months[memberSince.value!.month - 1]} ${memberSince.value!.year}';
  }

  /// Get status color
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';

// class GlobalVariables {
//   // COLORS

//   static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
//   static const secondaryColor = Color.fromRGBO(255, 153, 0, 1);
//   static const backgroundColor = Colors.white;
//   static const Color greyBackgroundCOlor = Color(0xffebecee);
//   static var selectedNavBarColor = Colors.cyan[800]!;
//   static const unselectedNavBarColor = Colors.black87;
// }

/// Fake data used only in debug builds (kDebugMode).
/// Remove this class (and its usage in location_service.dart) before release.
class FakeTestData {
  /// Returns a fake handyman placed ~500 m north-east of [userLat]/[userLon]
  /// so it always appears near the tester regardless of their real location.
  static Map<String, dynamic> nearbyHandyman(double userLat, double userLon) {
    return {
      'id': 'fake_handyman_test_001',
      'fullName': 'Ahmed Test (FAKE)',
      'category': 'Plumber',
      'rating': 4.8,
      'reviews': 32,
      'profilePicture': '',
      'isAvailable': true,
      // ~500 m north, ~700 m east
      'latitude': userLat + 0.005,
      'longitude': userLon + 0.007,
    };
  }
}

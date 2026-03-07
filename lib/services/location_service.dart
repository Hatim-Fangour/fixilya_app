import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:geolocator_apple/geolocator_apple.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ CHECK IF LOCATION SERVICES ARE ENABLED
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// ✅ GET CURRENT LOCATION
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkLocationPermission();
      if (!hasPermission) {
        if (kDebugMode) debugPrint('❌ Location permission denied');
        return null;
      }

      // Use platform-specific settings for accurate GPS fix
      late LocationSettings locationSettings;
      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: false, // use Google Play Services (FusedLocationProvider)
        );
      } else if (Platform.isIOS) {
        locationSettings = AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          activityType: ActivityType.other,
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        );
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );

      if (kDebugMode) {
        debugPrint(
          '✅ Current location: ${position.latitude}, ${position.longitude}',
        );
      }
      return position;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting location: $e');
      return null;
    }
  }

  /// ✅ GET CITY FROM CURRENT LOCATION
  Future<String?> getCityFromCurrentLocation() async {
    try {
      final position = await getCurrentLocation();
      if (position == null) return null;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality;
        if (kDebugMode) debugPrint('✅ Detected city: $city');
        return city?.isNotEmpty == true ? city : null;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error detecting city: $e');
      return null;
    }
  }

  /// ✅ GET ADDRESS FROM COORDINATES
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }

      return 'Unknown location';
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting address: $e');
      return 'Unknown location';
    }
  }

  /// ✅ SAVE CLIENT LOCATION TO FIREBASE
  Future<void> saveClientLocation(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('clients').doc(user.uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Client location saved');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving client location: $e');
    }
  }

  /// ✅ SAVE HANDYMAN LOCATION TO FIREBASE
  Future<void> saveHandymanLocation(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _firestore.collection('handymen').doc(user.uid).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });

      if (kDebugMode) debugPrint('✅ Handyman location saved');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error saving handyman location: $e');
    }
  }

  /// ✅ CALCULATE DISTANCE BETWEEN TWO POINTS (in kilometers)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
  }

  /// ✅ GET NEARBY HANDYMEN
  Future<List<Map<String, dynamic>>> getNearbyHandymen({
    required double userLat,
    required double userLon,
    double radiusKm = 50.0,
  }) async {
    try {
      final snapshot = await _firestore.collection('handymen').get();

      List<Map<String, dynamic>> nearbyHandymen = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Security: skip unapproved or suspended handymen
        // Firestore field names are 'approved' and 'suspended' (set by backend).
        if (data['approved'] != true) continue;
        if (data['suspended'] == true) continue;

        final privacy = (data['locationPrivacy'] as String?) ?? 'city_only';

        // 'on_booking_accept' → never shown on general map
        if (privacy == 'on_booking_accept') continue;

        double handymanLat;
        double handymanLon;
        bool isCityLevel = false;

        if (privacy == 'city_only') {
          // Use geocoded city centre instead of exact coords
          final city = data['city'] as String?;
          if (city == null || city.isEmpty) continue;
          try {
            final locations = await locationFromAddress(city);
            if (locations.isEmpty) continue;
            handymanLat = locations.first.latitude;
            handymanLon = locations.first.longitude;
            isCityLevel = true;
          } catch (_) {
            continue;
          }
        } else {
          // 'exact' or legacy null → use stored coords
          if (data['latitude'] == null || data['longitude'] == null) continue;
          handymanLat = (data['latitude'] as num).toDouble();
          handymanLon = (data['longitude'] as num).toDouble();
        }

        final distance = calculateDistance(
          userLat,
          userLon,
          handymanLat,
          handymanLon,
        );

        if (distance <= radiusKm) {
          nearbyHandymen.add({
            ...data,
            'id': doc.id,
            'latitude': handymanLat,
            'longitude': handymanLon,
            'distance': distance,
            if (isCityLevel) 'isCityLevel': true,
          });
        }
      }

      // Sort by distance
      nearbyHandymen.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      if (kDebugMode)
        debugPrint('✅ Found ${nearbyHandymen.length} nearby handymen');
      return nearbyHandymen;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error getting nearby handymen: $e');
      return [];
    }
  }

  /// ✅ OPEN GOOGLE MAPS NAVIGATION
  Future<void> openGoogleMapsNavigation(
    double destinationLat,
    double destinationLon,
  ) async {
    try {
      final url =
          'https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLon';

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (kDebugMode) debugPrint('❌ Could not open Google Maps');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error opening Google Maps: $e');
    }
  }
}

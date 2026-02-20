import 'package:geolocator/geolocator.dart';
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
        print('❌ Location permission denied');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ Current location: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      print('❌ Error getting location: $e');
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
      print('❌ Error getting address: $e');
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

      print('✅ Client location saved');
    } catch (e) {
      print('❌ Error saving client location: $e');
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

      print('✅ Handyman location saved');
    } catch (e) {
      print('❌ Error saving handyman location: $e');
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

        if (data['latitude'] != null && data['longitude'] != null) {
          double handymanLat = data['latitude'];
          double handymanLon = data['longitude'];

          double distance = calculateDistance(
            userLat,
            userLon,
            handymanLat,
            handymanLon,
          );

          if (distance <= radiusKm) {
            nearbyHandymen.add({...data, 'id': doc.id, 'distance': distance});
          }
        }
      }

      // Sort by distance
      nearbyHandymen.sort(
        (a, b) => (a['distance'] as double).compareTo(b['distance'] as double),
      );

      print('✅ Found ${nearbyHandymen.length} nearby handymen');
      return nearbyHandymen;
    } catch (e) {
      print('❌ Error getting nearby handymen: $e');
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
        print('❌ Could not open Google Maps');
      }
    } catch (e) {
      print('❌ Error opening Google Maps: $e');
    }
  }
}

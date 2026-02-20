import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fixilya_app/services/location_service.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:get/get.dart';

class HandymenMapPage extends StatefulWidget {
  const HandymenMapPage({super.key});

  @override
  State<HandymenMapPage> createState() => _HandymenMapPageState();
}

class _HandymenMapPageState extends State<HandymenMapPage> {
  final LocationService _locationService = LocationService();
  GoogleMapController? _mapController;

  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _handymen = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    setState(() => _isLoading = true);

    // Get current location
    final position = await _locationService.getCurrentLocation();

    if (position == null) {
      Get.snackbar(
        'Location Error',
        'Please enable location services',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() => _isLoading = false);
      return;
    }

    // Get nearby handymen
    final handymen = await _locationService.getNearbyHandymen(
      userLat: position.latitude,
      userLon: position.longitude,
      radiusKm: 50.0,
    );

    // Create markers
    Set<Marker> markers = {};

    // Add user location marker
    markers.add(
      Marker(
        markerId: MarkerId('my_location'),
        position: LatLng(position.latitude, position.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: 'Your Location'),
      ),
    );

    // Add handyman markers
    for (var handyman in handymen) {
      markers.add(
        Marker(
          markerId: MarkerId(handyman['id']),
          position: LatLng(handyman['latitude'], handyman['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: handyman['fullName'] ?? 'Handyman',
            snippet:
                '${handyman['category']} - ${handyman['distance'].toStringAsFixed(1)} km away',
          ),
          onTap: () => _showHandymanDetails(handyman),
        ),
      );
    }

    setState(() {
      _currentPosition = position;
      _handymen = handymen;
      _markers = markers;
      _isLoading = false;
    });

    // Move camera to user location
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        13,
      ),
    );
  }

  void _showHandymanDetails(Map<String, dynamic> handyman) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: NetworkImage(handyman['profilePicture'] ?? ''),
            ),
            SizedBox(height: 16),
            Text(
              handyman['fullName'] ?? 'Handyman',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(handyman['category'] ?? 'Service'),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 20),
                Text(' ${handyman['rating']} (${handyman['reviews']} reviews)'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '${handyman['distance'].toStringAsFixed(1)} km away',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Get.back();
                // Navigate to handyman details
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('View Profile'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby Handymen'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: Icon(Icons.my_location), onPressed: _loadMap),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _currentPosition == null
          ? Center(child: Text('Location not available'))
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 13,
                  ),
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

                // Handymen list at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 150,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.all(10),
                      itemCount: _handymen.length,
                      itemBuilder: (context, index) {
                        final handyman = _handymen[index];
                        return _buildHandymanCard(handyman);
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHandymanCard(Map<String, dynamic> handyman) {
    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHandymanDetails(handyman),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    handyman['profilePicture'] ?? '',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        handyman['fullName'] ?? 'Handyman',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        handyman['category'] ?? 'Service',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(
                            ' ${handyman['rating']}',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.location_on, size: 14, color: Colors.grey),
                          Text(
                            ' ${handyman['distance'].toStringAsFixed(1)} km',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

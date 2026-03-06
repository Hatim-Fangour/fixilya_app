import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/features/call/presentation/screens/call_screen.dart';
import 'package:fixilya_app/features/client/presentation/widgets/booking_dialog.dart'
    show showBookingDialog;
import 'package:fixilya_app/services/call_service.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fixilya_app/services/location_service.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:get/get.dart';

class HandymenMapPage extends StatefulWidget {
  const HandymenMapPage({super.key});

  @override
  State<HandymenMapPage> createState() => _HandymenMapPageState();
}

class _HandymenMapPageState extends State<HandymenMapPage> {
  final LocationService _locationService = LocationService();
  final HandymanApiService _handymanApi = HandymanApiService();
  GoogleMapController? _mapController;

  Position? _currentPosition;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _handymen = [];
  bool _isLoading = true;
  String? _errorMessage;
  double _radiusKm = 50.0;

  static const List<double> _radiusOptions = [10, 25, 50, 100];
  static const Color _primaryColor = Color(0xFF536EFE);

  // ─── Marker icon builder ────────────────────────────────────────────────────

  Future<BitmapDescriptor> _buildMarkerIcon(
    String name,
    String skill,
  ) async {
    const double w = 170;
    const double labelH = 56;
    const double pinH = 14;
    const double totalH = labelH + pinH;
    const double r = 10;
    const Color bg = _primaryColor;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(2, 3, w, labelH),
        const Radius.circular(r),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // Card background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, labelH),
        const Radius.circular(r),
      ),
      Paint()..color = bg,
    );

    // Pin triangle
    final pin = Path()
      ..moveTo(w / 2 - 9, labelH)
      ..lineTo(w / 2 + 9, labelH)
      ..lineTo(w / 2, totalH)
      ..close();
    canvas.drawPath(pin, Paint()..color = bg);

    // Name
    final namePainter = TextPainter(
      text: TextSpan(
        text: name.length > 20 ? '${name.substring(0, 18)}…' : name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 16);
    namePainter.paint(canvas, const Offset(8, 8));

    // Skill
    final skillPainter = TextPainter(
      text: TextSpan(
        text: skill.length > 24 ? '${skill.substring(0, 22)}…' : skill,
        style: const TextStyle(
          color: Color(0xFFD0D8FF),
          fontSize: 11,
          decoration: TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 16);
    skillPainter.paint(canvas, const Offset(8, 30));

    final pic = recorder.endRecording();
    final img = await pic.toImage(w.toInt(), totalH.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ─── Center on real GPS position ────────────────────────────────────────────

  Future<void> _centerOnMyLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position == null || !mounted) return;

    setState(() => _currentPosition = position);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15,
      ),
    );
  }

  // ─── Map loading ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadMap();
  }

  Future<void> _loadMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final position = await _locationService.getCurrentLocation();

    if (position == null) {
      Get.snackbar(
        'Location Error',
        'Please enable location services',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      setState(() {
        _isLoading = false;
        _errorMessage = 'Location not available';
      });
      return;
    }

    // Fetch nearby approved handymen from the backend API.
    // The backend handles approval filtering, privacy rules, and
    // distance calculation server-side.
    List<Map<String, dynamic>> handymen;
    try {
      handymen = await _handymanApi.getNearbyHandymen(
        lat: position.latitude,
        lon: position.longitude,
        radiusKm: _radiusKm,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('HandymenMapPage: API error: $e');
      handymen = [];
      if (mounted) {
        Get.snackbar(
          'Network Error',
          'Could not load nearby handymen. Please try again.',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }

    Set<Marker> markers = {};

    // No manual "my location" marker — the native blue dot from
    // myLocationEnabled: true is more accurate and updates in real-time.

    // Handyman markers with custom label icons
    for (var handyman in handymen) {
      final name = handyman['fullName'] as String? ?? 'Handyman';
      final skill = handyman['category'] as String? ?? 'Service';
      final isCityLevel = handyman['isCityLevel'] == true;

      BitmapDescriptor icon;
      if (isCityLevel) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      } else {
        icon = await _buildMarkerIcon(name, skill);
      }

      markers.add(
        Marker(
          markerId: MarkerId(handyman['id'] as String),
          position: LatLng(
            (handyman['latitude'] as num).toDouble(),
            (handyman['longitude'] as num).toDouble(),
          ),
          icon: icon,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _showHandymanDetails(handyman),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _currentPosition = position;
      _handymen = handymen;
      _markers = markers;
      _isLoading = false;
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        13,
      ),
    );

    if (handymen.isEmpty) {
      if (kDebugMode) debugPrint('HandymenMapPage: no handymen within $_radiusKm km');
    }
  }

  // ─── Calling ────────────────────────────────────────────────────────────────

  Future<void> _startCall(
    BuildContext sheetCtx,
    Map<String, dynamic> handyman,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to make calls')),
      );
      return;
    }

    // The document ID in the handymen collection IS the uid
    final handymanId = (handyman['uid'] ?? handyman['id']) as String?;
    if (handymanId == null || handymanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reach this handyman right now')),
      );
      return;
    }

    final handymanName = handyman['fullName'] as String? ?? 'Handyman';
    final handymanPicture = handyman['profilePicture'] as String?;

    // Resolve caller name
    String callerName = currentUser.displayName ?? 'Client';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists) {
        final d = doc.data();
        callerName =
            d?['fullName'] as String? ?? d?['name'] as String? ?? callerName;
      }
    } catch (_) {}

    // Dismiss bottom sheet using its own context, then use the Scaffold context
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();

    if (!mounted) return;

    // Loading spinner — use widget context (Scaffold), not the stale sheet context
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: _primaryColor),
      ),
    );

    try {
      final result = await CallService().initiateCall(
        calleeId:   handymanId,
        calleeName: handymanName,
        callerName: callerName,
      );

      final callId = result['callId'] ?? '';
      final agoraToken = result['token'];

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(
            callId: callId,
            remoteUid: handymanId,
            remoteName: handymanName,
            remotePicture: handymanPicture,
            isCaller: true,
            agoraToken: agoraToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Call failed: $e')),
      );
    }
  }

  // ─── Details popup ──────────────────────────────────────────────────────────

  void _showHandymanDetails(Map<String, dynamic> handyman) {
    final String? imageUrl = handyman['profilePicture'] as String?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final String name = handyman['fullName'] as String? ?? 'Handyman';
    final String skill = handyman['category'] as String? ?? 'Service';
    final double rating = (handyman['rating'] as num?)?.toDouble() ?? 0.0;
    final int reviews = (handyman['reviews'] as num?)?.toInt() ??
        (handyman['totalReviews'] as num?)?.toInt() ?? 0;
    final double distance = (handyman['distance'] as num?)?.toDouble() ?? 0.0;
    final String? phone = handyman['phoneNumber'] as String?;
    final bool isAvailable = handyman['isAvailable'] as bool? ?? false;
    final bool isCityLevel = handyman['isCityLevel'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey200Color(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Avatar + availability badge
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.grey200Color(context),
                  backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                  onBackgroundImageError: hasImage ? (e, s) {} : null,
                  child: !hasImage
                      ? Icon(
                          Icons.person,
                          size: 44,
                          color: AppColors.grey600Color(context),
                        )
                      : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cardColor(context),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    isAvailable ? 'Available' : 'Busy',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Name
            Text(
              name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 4),

            // Skill chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                skill,
                style: const TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Rating + distance row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  '$rating',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                Text(
                  '  ($reviews reviews)',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.textSecondaryColor(context),
                ),
                Text(
                  ' ${distance.toStringAsFixed(1)} km away',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            // Phone row (if available)
            if (phone != null && phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_outlined,
                    size: 15,
                    color: AppColors.textSecondaryColor(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      color: AppColors.textSecondaryColor(context),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // City-level note
            if (isCityLevel) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exact location shared on booking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons row: Call | Book | Navigate
            Row(
              children: [
                // Call
                Expanded(
                  child: _ActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: Colors.green,
                    onTap: () => _startCall(sheetCtx, handyman),
                  ),
                ),
                const SizedBox(width: 10),

                // Book
                Expanded(
                  child: _ActionButton(
                    icon: Icons.calendar_month_rounded,
                    label: 'Book',
                    color: _primaryColor,
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      // showBookingDialog uses showModalBottomSheet which
                      // provides the Material ancestor required by InkWell.
                      showBookingDialog(context, handyman);
                    },
                  ),
                ),
                if (!isCityLevel) ...[
                  const SizedBox(width: 10),

                  // Navigate (hidden for city-level markers)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.directions_rounded,
                      label: 'Navigate',
                      color: Colors.orange,
                      onTap: () {
                        _locationService.openGoogleMapsNavigation(
                          (handyman['latitude'] as num).toDouble(),
                          (handyman['longitude'] as num).toDouble(),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // View full profile — subtle text button
            TextButton(
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                AppRoutes.toHandymanDetails(handyman);
              },
              child: Text(
                'View full profile →',
                style: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Handymen'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh handymen',
            onPressed: _loadMap,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on my location',
            onPressed: _centerOnMyLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentPosition == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 64,
                    color: AppColors.textSecondaryColor(context),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Location not available',
                    style: TextStyle(color: AppColors.textPrimaryColor(context)),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadMap,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
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
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                ),

                // Radius filter chips
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: _buildRadiusFilter(),
                ),

                // Bottom list or empty state
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _handymen.isEmpty
                      ? _buildEmptyState()
                      : SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.all(10),
                            itemCount: _handymen.length,
                            itemBuilder: (context, index) =>
                                _buildHandymanCard(_handymen[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildRadiusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _radiusOptions.map((km) {
          final selected = _radiusKm == km;
          return ChoiceChip(
            label: Text('${km.toInt()} km'),
            selected: selected,
            selectedColor: _primaryColor,
            labelStyle: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.textPrimaryColor(context),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
            backgroundColor: AppColors.surfaceColor(context),
            onSelected: (_) {
              setState(() => _radiusKm = km);
              _loadMap();
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off,
            color: AppColors.textSecondaryColor(context),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            'No handymen found within ${_radiusKm.toInt()} km',
            style: TextStyle(
              color: AppColors.textSecondaryColor(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandymanCard(Map<String, dynamic> handyman) {
    final String? imageUrl = handyman['profilePicture'] as String?;
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final double distance = (handyman['distance'] as num?)?.toDouble() ?? 0.0;
    final num rating = (handyman['rating'] as num?) ?? 0;
    final bool isAvailable = handyman['isAvailable'] as bool? ?? false;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showHandymanDetails(handyman),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.grey200Color(context),
                      backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
                      onBackgroundImageError: hasImage ? (e, s) {} : null,
                      child: !hasImage
                          ? Icon(
                              Icons.person,
                              size: 30,
                              color: AppColors.grey600Color(context),
                            )
                          : null,
                    ),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.cardColor(context),
                          width: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
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
                          color: AppColors.textPrimaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        handyman['category'] ?? 'Service',
                        style: TextStyle(
                          color: AppColors.textSecondaryColor(context),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 16,
                          ),
                          Text(
                            ' $rating',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.textSecondaryColor(context),
                          ),
                          Text(
                            ' ${distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryColor(context),
                            ),
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

// ─── Reusable action button widget ──────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

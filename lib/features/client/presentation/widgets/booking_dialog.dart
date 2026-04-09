import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:fixilya_app/services/location_privacy_service.dart';
import 'package:fixilya_app/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingDialog extends StatefulWidget {
  final Map<String, dynamic> handyman;

  const BookingDialog({super.key, required this.handyman});

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _bookingsService = BookingsService();
  final _locationPrivacyService = LocationPrivacyService();
  final _locationService = LocationService();

  // Form controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Selected values
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  String? _selectedService;

  // Available time slots
  List<String> _availableTimeSlots = [];
  bool _loadingSlots = false;

  Set<DateTime> _unavailableDates = {};
  bool _loadingDates = false;

  // Location sharing
  bool _clientSharesLocation = false;
  double? _clientLatitude;
  double? _clientLongitude;
  bool _captureGps = false;

  // Premium colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);

  StreamSubscription? _bookingSubscription;
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUnavailableDates();
    _listenToBookingChanges();
    _loadClientLocationPreference();

    // ✅ DEBUG: Print handyman data to see what fields we have
    if (kDebugMode) debugPrint('🔍 HANDYMAN DATA IN BOOKING DIALOG:');
    widget.handyman.forEach((key, value) {
      if (kDebugMode) debugPrint('  $key: $value');
    });

    Future.delayed(Duration(seconds: 2), () {
      if (mounted && _loadingDates) {
        setState(() => _loadingDates = false);
        if (kDebugMode) debugPrint('⚠️ Force-stopped loading dates');
      }
    });
  }

  void _listenToBookingChanges() {
    final handymanId = _getHandymanId();
    if (handymanId.isEmpty) return;

    _bookingSubscription = FirebaseFirestore.instance
        .collection('bookings')
        .where('handymanId', isEqualTo: handymanId)
        .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
        .snapshots()
        .listen((snapshot) {
          // Update unavailable dates when bookings change
          _loadUnavailableDates();
        });
  }

  @override
  void dispose() {
    _bookingSubscription?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ✅ FIXED: Better handyman ID detection
  String _getHandymanId() {
    // Try different possible field names
    final possibleIds = [
      widget.handyman['uid'], // Firebase UID
      widget.handyman['id'], // Document ID
      widget.handyman['userId'], // User ID
      widget.handyman['handymanId'], // Handyman ID
    ];

    for (var id in possibleIds) {
      if (id != null && id.toString().isNotEmpty) {
        if (kDebugMode) debugPrint('✅ Found handyman ID: $id');
        return id.toString();
      }
    }

    if (kDebugMode) debugPrint('❌ ERROR: No handyman ID found!');
    if (kDebugMode) debugPrint('Available fields: ${widget.handyman.keys.join(", ")}');
    return '';
  }

  String _getHandymanName() {
    return widget.handyman['name'] ??
        widget.handyman['fullName'] ??
        widget.handyman['displayName'] ??
        'Handyman';
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();

      if (clientDoc.exists && mounted) {
        final data = clientDoc.data();
        setState(() {
          _nameController.text = data?['fullName'] ?? '';
          _phoneController.text = data?['phone'] ?? '';
          _addressController.text = data?['address'] ?? '';
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadClientLocationPreference() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final shares = await _locationPrivacyService.getClientSharePreference(uid);
      if (mounted) setState(() => _clientSharesLocation = shares);
    } catch (_) {}
  }

  Future<void> _captureClientLocation() async {
    setState(() => _captureGps = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _clientLatitude = pos.latitude;
          _clientLongitude = pos.longitude;
        });
      } else {
        Get.snackbar(
          'Location',
          'Could not get GPS. Please allow location access.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _captureGps = false);
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedDate == null) return;

    setState(() => _loadingSlots = true);

    try {
      final handymanId = _getHandymanId();

      if (handymanId.isEmpty) {
        if (kDebugMode) debugPrint('❌ Cannot load slots: No handyman ID');
        setState(() => _loadingSlots = false);
        return;
      }

      final slots = await _bookingsService.getAvailableTimeSlots(
        handymanId,
        _selectedDate!,
      );

      if (mounted) {
        setState(() {
          _availableTimeSlots = slots;
          _loadingSlots = false;
          // if (_selectedTimeSlot != null && !slots.contains(_selectedTimeSlot)) {
          //   _selectedTimeSlot = null;
          // }
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading slots: $e');
      if (mounted) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<void> _submitBooking() async {
    // ✅ VALIDATION
    if (!_formKey.currentState!.validate()) {
      if (kDebugMode) debugPrint('❌ Form validation failed');
      return;
    }

    if (_selectedDate == null ||
        // _selectedTimeSlot == null ||
        _selectedService == null) {
      Get.snackbar(
        'Missing Information',
        'Please select date, and service',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // ✅ GET HANDYMAN ID
    final handymanId = _getHandymanId();

    if (handymanId.isEmpty) {
      if (kDebugMode) debugPrint('❌ CRITICAL ERROR: No handyman ID available!');
      if (kDebugMode) debugPrint('Handyman data: ${widget.handyman}');

      Get.snackbar(
        'Error',
        'Unable to identify handyman. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // ✅ SHOW LOADING
    Get.dialog(
      Center(
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(height: 16),
              Text('Creating booking...'),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );

    try {
      // ✅ DEBUG LOGGING
      if (kDebugMode) debugPrint('📝 Booking Details:');
      if (kDebugMode) debugPrint('  Handyman ID: $handymanId');
      if (kDebugMode) debugPrint('  Handyman Name: ${_getHandymanName()}');
      if (kDebugMode) debugPrint('  Client Name: ${_nameController.text}');
      if (kDebugMode) debugPrint('  Service: $_selectedService');
      if (kDebugMode) debugPrint('  Date: $_selectedDate');
      if (kDebugMode) debugPrint('  Time Slot: $_selectedTimeSlot');
      if (kDebugMode) debugPrint('  Amount: ${widget.handyman['hourlyRate'] ?? 150}');

      final bookingId = await _bookingsService.createBooking(
        handymanId: handymanId,
        handymanName: _getHandymanName(),
        clientName: _nameController.text,
        clientPhone: _phoneController.text,
        service: _selectedService!,
        address: _addressController.text,
        city: widget.handyman['city'] ?? 'Unknown',
        scheduledDate: _selectedDate!,
        // timeSlot: _selectedTimeSlot!,
        description: _descriptionController.text,
        // estimatedPrice: (widget.handyman['hourlyRate'] ?? 150).toDouble(),
        clientLatitude: _clientLatitude,
        clientLongitude: _clientLongitude,
      );

      // Close loading
      Get.back();

      if (bookingId != null) {
        if (kDebugMode) debugPrint('✅ Booking created successfully: $bookingId');

        // Close dialog
        Get.back();

        // Show success
        Get.snackbar(
          '✅ Booking Created',
          'Your booking request has been sent to ${_getHandymanName()}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
          icon: Icon(Icons.check_circle, color: Colors.white),
        );
      } else {
        if (kDebugMode) debugPrint('❌ Booking creation returned null');
        Get.snackbar(
          'Error',
          'Failed to create booking. Please try again.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.back(); // Close loading
      if (kDebugMode) debugPrint('❌ Error submitting booking: $e');
      Get.snackbar(
        'Error',
        'An error occurred: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _loadUnavailableDates() async {
    setState(() => _loadingDates = true);

    try {
      final handymanId = _getHandymanId();

      if (handymanId.isEmpty) {
        if (kDebugMode) debugPrint('❌ Cannot load unavailable dates: No handyman ID');
        setState(() => _loadingDates = false);
        return;
      }

      // Fetch all confirmed/active bookings for this handyman
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('handymanId', isEqualTo: handymanId)
          .where('status', whereIn: ['pending', 'confirmed', 'in_progress'])
          .get();

      Set<DateTime> bookedDates = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final scheduledDate = data['scheduledDate'];

        if (scheduledDate != null) {
          DateTime date;

          if (scheduledDate is Timestamp) {
            date = scheduledDate.toDate();
          } else if (scheduledDate is DateTime) {
            date = scheduledDate;
          } else {
            continue;
          }

          // Normalize to midnight (remove time portion)
          final normalizedDate = DateTime(date.year, date.month, date.day);
          bookedDates.add(normalizedDate);
        }
      }

      if (mounted) {
        setState(() {
          _unavailableDates = bookedDates;
          _loadingDates = false;
        });

        if (kDebugMode) debugPrint('✅ Loaded ${_unavailableDates.length} unavailable dates');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading unavailable dates: $e');
      if (mounted) {
        setState(() => _loadingDates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor(context),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.calendar_month,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Book Appointment',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      Text(
                        'with ${_getHandymanName()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: AppColors.dividerColor(context)),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service selection
                    Text(
                      'Select Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _getServices().map((service) {
                        final isSelected = _selectedService == service;
                        return InkWell(
                          onTap: () =>
                              setState(() => _selectedService = service),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primaryColor,
                                        AppColors.secondaryColor,
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : AppColors.cardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : AppColors.borderColor(context),
                              ),
                            ),
                            child: Text(
                              service,
                              style: TextStyle(
                                color: isSelected
                                    ? AppColors.white
                                    : AppColors.textSecondaryColor(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    SizedBox(height: 24),

                    // Name
                    _buildTextField(
                      controller: _nameController,
                      label: 'Your Name',
                      icon: Icons.person_outline,
                      validator: (val) =>
                          val?.isEmpty ?? true ? 'Required' : null,
                    ),

                    SizedBox(height: 16),

                    // Phone
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (val) =>
                          val?.isEmpty ?? true ? 'Required' : null,
                    ),

                    SizedBox(height: 16),

                    // Address
                    _buildTextField(
                      controller: _addressController,
                      label: 'Service Address',
                      icon: Icons.location_on_outlined,
                      maxLines: 2,
                      validator: (val) =>
                          val?.isEmpty ?? true ? 'Required' : null,
                    ),

                    // My Location row (shown only when client opted in)
                    if (_clientSharesLocation) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardColor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.borderColor(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.share_location,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Location',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    _clientLatitude != null
                                        ? '${_clientLatitude!.toStringAsFixed(5)}, ${_clientLongitude!.toStringAsFixed(5)}'
                                        : 'Not captured yet',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _clientLatitude != null
                                          ? AppColors.textPrimaryColor(context)
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _captureGps
                                ? SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        primaryColor,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: Icon(
                                      Icons.gps_fixed,
                                      color: primaryColor,
                                    ),
                                    tooltip: 'Capture GPS',
                                    onPressed: _captureClientLocation,
                                  ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 24),

                    // Date selection
                    Text(
                      'Select Date',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    SizedBox(height: 12),

                    InkWell(
                      onTap: _loadingDates ? null : _selectDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceColor(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _loadingDates
                                ? Colors
                                      .grey
                                      .shade400 // ✅ Different color when loading
                                : AppColors.borderColor(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    AppColors.secondaryColor.withValues(
                                      alpha: 0.05,
                                    ),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child:
                                  _loadingDates // ✅ Show loading indicator
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          AppColors.primaryColor,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.calendar_today,
                                      color: AppColors.primaryColor,
                                      size: 20,
                                    ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _loadingDates ? 'Loading dates...' : 'Date',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    _selectedDate == null
                                        ? 'Choose a date'
                                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDate == null
                                          ? Colors.grey
                                          : AppColors.textPrimaryColor(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // if (_selectedDate != null) ...[
                    //   SizedBox(height: 16),

                    //   // Time slots
                    //   Text(
                    //     'Available Time Slots',
                    //     style: TextStyle(
                    //       fontSize: 14,
                    //       fontWeight: FontWeight.w600,
                    //       color: Colors.black87,
                    //     ),
                    //   ),
                    //   SizedBox(height: 12),

                    //   if (_loadingSlots)
                    //     Center(
                    //       child: Padding(
                    //         padding: EdgeInsets.all(20),
                    //         child: CircularProgressIndicator(
                    //           color: primaryColor,
                    //         ),
                    //       ),
                    //     )
                    //   else if (_availableTimeSlots.isEmpty)
                    //     Container(
                    //       padding: EdgeInsets.all(20),
                    //       decoration: BoxDecoration(
                    //         color: Colors.orange[50],
                    //         borderRadius: BorderRadius.circular(12),
                    //         border: Border.all(color: Colors.orange[200]!),
                    //       ),
                    //       child: Row(
                    //         children: [
                    //           Icon(Icons.info_outline, color: Colors.orange),
                    //           SizedBox(width: 12),
                    //           Expanded(
                    //             child: Text(
                    //               'No available slots for this date. Please choose another date.',
                    //               style: TextStyle(color: Colors.orange[900]),
                    //             ),
                    //           ),
                    //         ],
                    //       ),
                    //     )
                    //   else
                    //     Wrap(
                    //       spacing: 10,
                    //       runSpacing: 10,
                    //       children: _availableTimeSlots.map((slot) {
                    //         final isSelected = _selectedTimeSlot == slot;
                    //         return InkWell(
                    //           onTap: () =>
                    //               setState(() => _selectedTimeSlot = slot),
                    //           borderRadius: BorderRadius.circular(10),
                    //           child: Container(
                    //             padding: EdgeInsets.symmetric(
                    //               horizontal: 14,
                    //               vertical: 12,
                    //             ),
                    //             decoration: BoxDecoration(
                    //               gradient: isSelected
                    //                   ? LinearGradient(
                    //                       colors: [
                    //                         primaryColor,
                    //                         secondaryColor,
                    //                       ],
                    //                     )
                    //                   : null,
                    //               color: isSelected ? null : Colors.white,
                    //               borderRadius: BorderRadius.circular(10),
                    //               border: Border.all(
                    //                 color: isSelected
                    //                     ? Colors.transparent
                    //                     : Colors.grey[300]!,
                    //                 width: 1.5,
                    //               ),
                    //             ),
                    //             child: Row(
                    //               mainAxisSize: MainAxisSize.min,
                    //               children: [
                    //                 Icon(
                    //                   Icons.access_time,
                    //                   size: 16,
                    //                   color: isSelected
                    //                       ? Colors.white
                    //                       : primaryColor,
                    //                 ),
                    //                 SizedBox(width: 6),
                    //                 Text(
                    //                   slot,
                    //                   style: TextStyle(
                    //                     color: isSelected
                    //                         ? Colors.white
                    //                         : Colors.black87,
                    //                     fontWeight: FontWeight.w600,
                    //                     fontSize: 13,
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //         );
                    //       }).toList(),
                    //     ),
                    // ],
                    SizedBox(height: 24),

                    // Description
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Additional Details (Optional)',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),

                    SizedBox(height: 24),

                    // Price estimate
                    // Container(
                    //   padding: EdgeInsets.all(16),
                    //   decoration: BoxDecoration(
                    //     gradient: LinearGradient(
                    //       colors: [
                    //         primaryColor.withOpacity(0.1),
                    //         secondaryColor.withOpacity(0.05),
                    //       ],
                    //     ),
                    //     borderRadius: BorderRadius.circular(14),
                    //     border: Border.all(
                    //       color: primaryColor.withOpacity(0.2),
                    //     ),
                    //   ),
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //     children: [
                    //       Text(
                    //         'Estimated Price',
                    //         style: TextStyle(
                    //           fontSize: 14,
                    //           fontWeight: FontWeight.w600,
                    //           color: Colors.grey[700],
                    //         ),
                    //       ),
                    //       Text(
                    //         '${widget.handyman['hourlyRate'] ?? 150} DH/hour',
                    //         style: TextStyle(
                    //           fontSize: 18,
                    //           fontWeight: FontWeight.bold,
                    //           color: primaryColor,
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom action button
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor(context),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _submitBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 22,
                        color: Colors.white,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Confirm Booking',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.9,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: AppColors.textSecondaryColor(context),
        ),
        prefixIcon: Container(
          margin: EdgeInsets.all(12),
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primaryColor.withOpacity(0.1),
                secondaryColor.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        filled: true,
        fillColor: AppColors.surfaceColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.borderColor(context),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Future<void> _selectDate() async {
    if (kDebugMode) debugPrint('📅 Opening date picker...');
    if (kDebugMode) debugPrint('Loading dates: $_loadingDates');
    if (kDebugMode) debugPrint('Unavailable dates: ${_unavailableDates.length}');

    try {
      // ✅ Find the first available date
      DateTime initialDate = DateTime.now().add(Duration(days: 1));
      final maxDays = 90;

      for (int i = 1; i <= maxDays; i++) {
        final testDate = DateTime.now().add(Duration(days: i));
        final normalizedDate = DateTime(
          testDate.year,
          testDate.month,
          testDate.day,
        );

        if (!_unavailableDates.contains(normalizedDate)) {
          initialDate = testDate;
          if (kDebugMode) debugPrint('✅ First available date: $initialDate');
          break;
        }
      }

      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate, // ✅ Use the first available date
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(Duration(days: 90)),

        selectableDayPredicate: (DateTime date) {
          try {
            final normalizedDate = DateTime(date.year, date.month, date.day);
            return !_unavailableDates.contains(normalizedDate);
          } catch (e) {
            if (kDebugMode) debugPrint('❌ Error in selectableDayPredicate: $e');
            return true;
          }
        },

        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              primaryColor: AppColors.primaryColor,
              colorScheme: ColorScheme.light(primary: AppColors.primaryColor),
              buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
            ),
            child: child!,
          );
        },
      );

      if (kDebugMode) debugPrint('✅ Date picker result: $picked');

      if (picked != null && picked != _selectedDate) {
        setState(() {
          _selectedDate = picked;
          _selectedTimeSlot = null;
        });
        await _loadAvailableSlots();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error opening date picker: $e');

      Get.snackbar(
        'Error',
        'Could not open date picker',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  List<String> _getServices() {
    // ✅ Get skills from handyman data
    final skills = widget.handyman['skills'];

    if (skills != null && skills is List && skills.isNotEmpty) {
      return skills.map((skill) => skill.toString()).toList();
    }

    // ✅ Return empty list or default message
    return ['Service'];
  }
}

// Helper function to show booking dialog
void showBookingDialog(BuildContext context, Map<String, dynamic> handyman) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => BookingDialog(handyman: handyman),
  );
}

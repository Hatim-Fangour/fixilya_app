import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientBookingsPage extends StatefulWidget {
  const ClientBookingsPage({super.key});

  @override
  State<ClientBookingsPage> createState() => _ClientBookingsPageState();
}

class _ClientBookingsPageState extends State<ClientBookingsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  StreamSubscription<QuerySnapshot>? _bookingsSub;

  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Active',
    'Pending',
    'Completed',
    'Cancelled',
    'Declined',
  ];

  List<Map<String, dynamic>> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _subscribeToBookings();
  }

  void _subscribeToBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    _bookingsSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _bookings = snap.docs
              .map((d) => {'id': d.id, ...(d.data() as Map<String, dynamic>)})
              .toList();
          _isLoading = false;
        });
      }
    }, onError: (e) {
      if (kDebugMode) debugPrint('❌ Bookings stream error: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _completeBookingWithReview(
    Map<String, dynamic> booking,
    int rating,
    String comment,
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final bookingId = booking['id'];
      final handymanId = booking['handymanId'];
      final clientId = booking['clientId'];

      final clientName = booking['clientName'] as String? ?? 'Client';
      final service = booking['service'] as String? ?? 'service';
      final reviewComment = comment.trim().isEmpty ? 'Great service!' : comment.trim();

      // 1. Create Review (with clientName so handyman's review page shows it)
      await firestore.collection('reviews').add({
        'bookingId': bookingId,
        'handymanId': handymanId,
        'clientId': clientId,
        'clientName': clientName,
        'rating': rating,
        'comment': reviewComment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Booking Status + denormalise review so both sides can read it from the booking doc
      await firestore.collection('bookings').doc(bookingId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'rating': rating,
        'reviewComment': reviewComment,
      });

      // 3. Update Handyman Stats
      final handymanDoc = await firestore
          .collection('handymen')
          .doc(handymanId)
          .get();

      if (handymanDoc.exists) {
        final currentRating =
            (handymanDoc.data()?['rating'] as num?)?.toDouble() ?? 0.0;
        final currentReviews = handymanDoc.data()?['reviews'] as int? ?? 0;
        final completedJobs = handymanDoc.data()?['completedJobs'] as int? ?? 0;

        final totalRating = (currentRating * currentReviews) + rating;
        final newReviews = currentReviews + 1;
        final newRating = totalRating / newReviews;

        await firestore.collection('handymen').doc(handymanId).update({
          'rating': double.parse(newRating.toStringAsFixed(1)),
          'reviews': newReviews,
          'completedJobs': completedJobs + 1,
        });
      }

      // 4. Notify handyman that client marked job as completed
      await firestore.collection('notifications').add({
        'userId': handymanId,
        'type': 'job_completed',
        'title': 'Job Marked as Completed',
        'message': '$clientName has marked your $service booking as completed',
        'bookingId': bookingId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 5. Switch to Completed tab — stream auto-updates the list
      if (mounted) setState(() => _selectedFilter = 'Completed');

      // 5. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Booking completed & review submitted!')),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
        ),
      );

      if (kDebugMode) debugPrint('✅ Booking completed with $rating star review');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error completing booking: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Failed to complete booking. Please try again.'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'confirmed':
      case 'in_progress':
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'declined':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_selectedFilter == 'All') return _bookings;

    return _bookings.where((booking) {
      final status = booking['status'].toString().toLowerCase();

      switch (_selectedFilter.toLowerCase()) {
        case 'active':
          return status == 'confirmed' || status == 'in_progress';
        case 'pending':
          return status == 'pending';
        case 'completed':
          return status == 'completed';
        case 'cancelled':
          return status == 'cancelled';
        case 'declined':
          return status == 'declined';
        default:
          return true;
      }
    }).toList();
  }

  int get _totalBookings => _bookings.length;
  int get _activeBookings => _bookings
      .where((b) => b['status'] == 'confirmed' || b['status'] == 'in_progress')
      .length;
  int get _pendingBookings =>
      _bookings.where((b) => b['status'] == 'pending').length;
  int get _completedBookings =>
      _bookings.where((b) => b['status'] == 'completed').length;

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is Map) {
        // Firestore Timestamp serialised as {_seconds, _nanoseconds} from REST API
        final seconds = (timestamp['_seconds'] as num?) ?? (timestamp['seconds'] as num?);
        if (seconds == null) return 'N/A';
        date = DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      } else {
        return 'N/A';
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

      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '${months[date.month - 1]} ${date.day}, ${date.year} at $h:$m';
    } catch (e) {
      return 'N/A';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.subtleHeaderGradientThemed(context),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 60, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.clipboardList,
                                color: AppColors.primaryColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Bookings',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${_filteredBookings.length} bookings',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState()
                : FadeTransition(
                    opacity: _animationController,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total',
                                  '$_totalBookings',
                                  Colors.blue,
                                  FontAwesomeIcons.chartLine,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Active',
                                  '$_activeBookings',
                                  Colors.green,
                                  FontAwesomeIcons.clipboardCheck,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Pending',
                                  '$_pendingBookings',
                                  Colors.orange,
                                  FontAwesomeIcons.clock,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Completed',
                                  '$_completedBookings',
                                  AppColors.primaryColor,
                                  FontAwesomeIcons.circleCheck,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((filter) {
                                final isSelected = _selectedFilter == filter;
                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(filter),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedFilter = filter);
                                    },
                                    backgroundColor: AppColors.cardColor(
                                      context,
                                    ),
                                    selectedColor: AppColors.primaryColor
                                        .withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? AppColors.primaryColor
                                          : AppColors.textSecondaryColor(
                                              context,
                                            ),
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? AppColors.primaryColor
                                          : AppColors.borderColor(context),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    showCheckmark: false,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Bookings List
                          if (_filteredBookings.isEmpty)
                            _buildEmptyState()
                          else
                            ..._filteredBookings
                                .map((booking) => _buildBookingCard(booking))
                                ,

                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            SizedBox(height: 20),
            Text(
              'Loading bookings...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.clipboardList,
                size: 48,
                color: AppColors.primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No bookings found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try changing the filter',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, color: color, size: 18),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final status = booking['status'];
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showBookingDetails(booking),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    booking['id'] ?? 'N/A',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            booking['handymanName'] ?? 'Unknown Handyman',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimaryColor(context),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            booking['service'] ?? 'Service',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondaryColor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Text(
                        //   '${booking['amount'] ?? 0} DH',
                        //   style: TextStyle(
                        //     fontSize: 20,
                        //     fontWeight: FontWeight.bold,
                        //     color: AppColors.primaryColor,
                        //   ),
                        // ),
                        // SizedBox(height: 4),
                        Text(
                          _formatDate(booking['createdAt']),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(height: 1, color: AppColors.dividerColor(context)),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking['address'] ?? 'N/A',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryColor(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.textSecondaryColor(context),
                    ),
                    SizedBox(width: 6),
                    Text(
                      _formatDate(booking['scheduledAt'] ?? booking['scheduledDate']),
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
        ),
      ),
    );
  }

  void _showBookingDetails(Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor,
                              AppColors.secondaryColor,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.clipboardList,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        booking['id'] ?? 'Booking Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            booking['status'],
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          booking['status'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(booking['status']),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildDetailRow(
                      'Handyman',
                      booking['handymanName'] ?? 'N/A',
                    ),
                    _buildDetailRow('Service', booking['service'] ?? 'N/A'),
                    _buildDetailRow('Phone', booking['clientPhone'] ?? 'N/A'),
                    _buildDetailRow('Address', booking['address'] ?? 'N/A'),
                    _buildDetailRow('City', booking['city'] ?? 'N/A'),
                    _buildDetailRow(
                      'Scheduled Date',
                      _formatDate(booking['scheduledAt'] ?? booking['scheduledDate']),
                    ),
                    _buildDetailRow(
                      'Booked At',
                      _formatDate(booking['createdAt']),
                    ),
                    if (booking['acceptedAt'] != null)
                      _buildDetailRow(
                        'Accepted At',
                        _formatDate(booking['acceptedAt']),
                      ),
                    if (booking['declinedAt'] != null)
                      _buildDetailRow(
                        'Declined At',
                        _formatDate(booking['declinedAt']),
                      ),
                    if ((booking['declineReason'] ?? booking['cancellationReason']) != null)
                      _buildDeclineReasonCard(
                        booking['declineReason'] ?? booking['cancellationReason'],
                      ),
                    if (booking['description'] != null &&
                        booking['description'].isNotEmpty) ...[
                      SizedBox(height: 16),
                      Text(
                        'Description',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        booking['description'],
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                    // ── Review (only if completed and has rating) ──
                    if (booking['status']?.toLowerCase() == 'completed' &&
                        booking['rating'] != null) ...[
                      SizedBox(height: 20),
                      _buildReviewCard(
                        rating: (booking['rating'] as num).toInt(),
                        comment: booking['reviewComment'] as String? ?? '',
                        label: 'Your Review',
                      ),
                    ],
                    // ✅ COMPLETE BUTTON (only if confirmed)
                    if (booking['status']?.toLowerCase() == 'confirmed') ...[
                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context); // Close details sheet
                            _showRatingDialog(booking); // Show rating dialog
                          },
                          icon: FaIcon(FontAwesomeIcons.circleCheck, size: 20),
                          label: Text(
                            'Mark as Completed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(Map<String, dynamic> booking) {
    int rating = 0;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.secondaryColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.star,
                    color: Colors.white,
                    size: 32,
                  ),
                ),

                SizedBox(height: 20),

                // Title
                Text(
                  'Rate Your Experience',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'How was ${booking['handymanName']}?',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 24),

                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() => rating = index + 1);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          size: 40,
                          color: index < rating
                              ? Colors.amber
                              : Colors.grey[400],
                        ),
                      ),
                    );
                  }),
                ),

                SizedBox(height: 24),

                // Comment TextField
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your experience (optional)',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondaryColor(context),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.borderColor(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: AppColors.borderColor(context),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 12),

                    // Submit Button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting || rating == 0
                            ? null
                            : () async {
                                setDialogState(() => isSubmitting = true);

                                await _completeBookingWithReview(
                                  booking,
                                  rating,
                                  commentController.text,
                                );

                                Navigator.pop(context); // Close dialog
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                'Submit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard({required int rating, required String comment, required String label}) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade700),
              SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: Colors.amber,
                size: 22,
              ),
            ),
          ),
          if (comment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 13,
                color: Colors.amber.shade900,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeclineReasonCard(String reason) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade400),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decline Reason',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryColor(context),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimaryColor(context),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

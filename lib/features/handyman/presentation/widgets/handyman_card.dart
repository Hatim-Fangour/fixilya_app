import 'package:flutter/foundation.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/features/call/presentation/screens/call_screen.dart';
import 'package:fixilya_app/features/client/presentation/widgets/booking_dialog.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/info_chip.dart';
import 'package:fixilya_app/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Handyman Card Widget
class HandymanCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const HandymanCard({super.key, required this.job});

  // ─── In-app voice call ───────────────────────────────────────────────────

  Future<void> _startCall(BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to make calls')),
      );
      return;
    }

    if (kDebugMode) debugPrint("job : ${job}");
    final handymanId = job['uid'] as String?;

    if (handymanId == null || handymanId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot reach this handyman right now')),
      );
      return;
    }

    // Resolve caller display name from Firestore, fall back to FirebaseAuth
    String callerName = currentUser.displayName ?? 'Client';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        callerName =
            data?['fullName'] as String? ??
            data?['name'] as String? ??
            callerName;
      }
    } catch (_) {}

    final handymanName = job['fullName'] as String? ?? 'Handyman';
    final handymanPicture = job['profilePicture'] as String?;

    // Show loading while Firestore doc is created
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
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

      if (!context.mounted) return;
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
      if (context.mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Call failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputFillColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(context),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: InkWell(
        onTap: () => AppRoutes.toHandymanDetails(job),

        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.borderColor(context),
                        width: 1,
                      ),
                      gradient:
                          job['profilePicture'] == null ||
                              job['profilePicture'].isEmpty
                          ? LinearGradient(
                              colors: [
                                AppColors.primaryColor,
                                AppColors.secondaryColor,
                              ],
                            )
                          : null,
                    ),
                    child:
                        job['profilePicture'] != null &&
                            job['profilePicture'].isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              job['profilePicture'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildAvatarFallback(job['fullName']);
                              },
                            ),
                          )
                        : _buildAvatarFallback(job['fullName']),
                  ),

                  SizedBox(width: 15),

                  // Name and Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job['fullName'] ?? 'Unnamed Handyman',

                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Verified = Approved
                            if (job['approved'] == true)
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.infoColor(
                                      context,
                                    ).withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),

                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.circleCheck,
                                      size: 10,
                                      color: AppColors.primaryColor,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Verified',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: 3),

                        Text(
                          job['category'] ??
                              (job['skills'] is List &&
                                      (job['skills'] as List).isNotEmpty
                                  ? (job['skills'] as List).first.toString()
                                  : 'Handyman'),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        SizedBox(height: 6),

                        // Rating
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.solidStar,
                              size: 12,
                              color: AppColors.amber,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '${job['rating']}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: AppColors.textPrimaryColor(context),
                              ),
                            ),
                            SizedBox(width: 3),
                            Text(
                              '(${job['reviews']})',
                              style: TextStyle(
                                fontSize: 11,
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

              SizedBox(height: 20),

              // Info Row & Action Buttons
              Row(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      InfoChip(
                        icon: FontAwesomeIcons.locationDot,
                        label: job['city'],
                        color: AppColors.cityColor,
                      ),
                      InfoChip(
                        icon: FontAwesomeIcons.briefcase,
                        label: '${job['completedJobs']} jobs',
                        color: AppColors.jobs,
                      ),
                      InfoChip(
                        icon: FontAwesomeIcons.clock,
                        label: job['experience'] ?? '—',
                        color: AppColors.experience,
                      ),
                    ],
                  ),

                  Spacer(),

                  // In-app Call button
                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.infoColor(context),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      onPressed: () => _startCall(context),
                      icon: FaIcon(FontAwesomeIcons.phone, size: 14),
                      color: AppColors.infoColor(context),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      constraints: BoxConstraints(),
                    ),
                  ),

                  SizedBox(width: 6),

                  Container(
                    height: 34,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.mainButtonColor(context),
                          AppColors.infoColor(context),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showBookingDialog(context, job);
                      },
                      icon: FaIcon(FontAwesomeIcons.calendarCheck, size: 12),
                      label: Text(
                        'Book',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.transparent,
                        foregroundColor: AppColors.white,
                        shadowColor: AppColors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size(0, 34),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    String initial = name.isNotEmpty ? name[0].toUpperCase() : 'H';

    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

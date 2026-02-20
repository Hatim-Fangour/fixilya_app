import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/features/client/presentation/widgets/booking_dialog.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/info_chip.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Handyman Card Widget
class HandymanCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const HandymanCard({super.key, required this.job});

  void print(job) {
    print('--- Handyman Card Data ---');
    print('Name: ${job['name']}');
    print('Category: ${job['category']}');
    print('Rating: ${job['rating']}');
    print('Reviews: ${job['reviews']}');
    print('City: ${job['city']}');
    print('Completed Jobs: ${job['completedJobs']}');
    print('Experience: ${job['experience']}');
    print('Phone: ${job['phone']}');
    print('Verified: ${job['verified']}');
    print('Image URL: ${job['image']}');
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // surfaceTintColor: AppColors.surfaceColor(context),
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
                                return _buildAvatarFallback(job['name']);
                              },
                            ),
                          )
                        : _buildAvatarFallback(job['name']),
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
                                job['name'],
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
                            if (job['verified'])
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
                          job['category'],
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
                        label: job['experience'],
                        color: AppColors.experience,
                      ),
                    ],
                  ),

                  Spacer(),
                  // Phone/ Book Handyman
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
                      onPressed: () {
                        _makePhoneCall(AppConfig.supportPhone);
                        // _makePhoneCall(job['phone']);
                        print('Calling ${job['phone']}');
                      },
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

              // SizedBox(height: 10),

              // // Price and Actions Row
              // Row(
              //   children: [
              //     // Price
              //     // Container(
              //     //   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              //     //   decoration: BoxDecoration(
              //     //     gradient: LinearGradient(
              //     //       colors: [
              //     //         AppColors.primaryColor.withValues(alpha: 0.1),
              //     //         AppColors.secondaryColor.withValues(alpha: 0.1),
              //     //       ],
              //     //     ),
              //     //     borderRadius: BorderRadius.circular(8),
              //     //     border: Border.all(
              //     //       color: AppColors.primaryColor.withValues(alpha: 0.2),
              //     //       width: 1,
              //     //     ),
              //     //   ),
              //     //   child: Row(
              //     //     mainAxisSize: MainAxisSize.min,
              //     //     children: [
              //     //       FaIcon(
              //     //         FontAwesomeIcons.moneyBill,
              //     //         size: 12,
              //     //         color: AppColors.primaryColor,
              //     //       ),
              //     //       SizedBox(width: 5),
              //     //       // Text(
              //     //       //   '${job['hourlyRate']} DH/h',
              //     //       //   style: TextStyle(
              //     //       //     fontSize: 13,
              //     //       //     fontWeight: FontWeight.bold,
              //     //       //     color: AppColors.primaryColor,
              //     //       //   ),
              //     //       // ),
              //     //     ],
              //     //   ),
              //     // ),
              //     Spacer(),

              //     // Call Button

              //     // Book Button
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    // Get first letter of name
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

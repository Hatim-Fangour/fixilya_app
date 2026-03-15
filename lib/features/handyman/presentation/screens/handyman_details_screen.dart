import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/models/handyman_model.dart';
import 'package:fixilya_app/data/models/review_model.dart';
import 'package:fixilya_app/features/booking/presentation/screens/booking_screen.dart';
import 'package:fixilya_app/features/chat/presentation/screens/chat_room_screen.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/info_chip.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Handyman details screen.
///
/// Displays a handyman's profile header, services offered, reviews, and
/// provides contact / booking actions.
class HandymanDetailsScreen extends StatelessWidget {
  final HandymanModel handyman;

  const HandymanDetailsScreen({super.key, required this.handyman});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildBody(context)),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ─── Sliver app bar with avatar ──────────────────────────────────────────

  SliverAppBar _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: AppColors.primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryColor, AppColors.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Avatar
                CircleAvatar(
                  radius: 44,
                  backgroundImage: handyman.image.isNotEmpty
                      ? NetworkImage(handyman.image)
                      : null,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: handyman.image.isEmpty
                      ? Text(
                          handyman.name.isNotEmpty
                              ? handyman.name[0].toUpperCase()
                              : 'H',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  handyman.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Category & verified badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      handyman.category,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (handyman.verified) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.verified, color: Colors.white, size: 18),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Body ────────────────────────────────────────────────────────────────

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row
          _buildStatsRow(context),
          const SizedBox(height: 24),

          // Info chips
          _buildInfoChips(context),
          const SizedBox(height: 24),

          // About section
          _buildSectionTitle(context, 'About'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  context,
                  FontAwesomeIcons.locationDot,
                  handyman.city,
                  AppColors.cityColor,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  context,
                  FontAwesomeIcons.briefcase,
                  '${handyman.experience} experience',
                  AppColors.experience,
                ),
                const SizedBox(height: 10),
                _infoRow(
                  context,
                  FontAwesomeIcons.moneyBill,
                  '${handyman.hourlyRate.toStringAsFixed(0)} DH/hr',
                  AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reviews section
          _buildSectionTitle(context, 'Reviews'),
          const SizedBox(height: 8),
          _buildReviewsList(context),
          const SizedBox(height: 80), // Space for bottom bar
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        _statCard(
          context,
          icon: FontAwesomeIcons.star,
          value: handyman.rating.toStringAsFixed(1),
          label: 'Rating',
          color: AppColors.reviews,
        ),
        const SizedBox(width: 12),
        _statCard(
          context,
          icon: FontAwesomeIcons.comment,
          value: '${handyman.reviews}',
          label: 'Reviews',
          color: AppColors.info,
        ),
        const SizedBox(width: 12),
        _statCard(
          context,
          icon: FontAwesomeIcons.checkDouble,
          value: '${handyman.completedJobs}',
          label: 'Jobs Done',
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor(context)),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryColor(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        InfoChip(
          icon: FontAwesomeIcons.wrench,
          label: handyman.category,
          color: AppColors.primaryColor,
        ),
        if (handyman.verified)
          const InfoChip(
            icon: FontAwesomeIcons.shieldHalved,
            label: 'Verified',
            color: AppColors.success,
          ),
        InfoChip(
          icon: FontAwesomeIcons.locationDot,
          label: handyman.city,
          color: AppColors.cityColor,
        ),
      ],
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      children: [
        FaIcon(icon, size: 14, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: AppColors.textPrimaryColor(context),
      ),
    );
  }

  // ─── Reviews list from Firestore ─────────────────────────────────────────

  Widget _buildReviewsList(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('handymanId', isEqualTo: handyman.id)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline, color: AppColors.error, size: 32),
                const SizedBox(height: 8),
                Text(
                  'Failed to load reviews',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderColor(context)),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined,
                    size: 40, color: AppColors.grey400),
                const SizedBox(height: 8),
                Text(
                  'No reviews yet',
                  style: TextStyle(
                    color: AppColors.textSecondaryColor(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            final review = ReviewModel.fromJson(data);
            return _ReviewCard(review: review);
          }).toList(),
        );
      },
    );
  }

  // ─── Bottom action bar ───────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Chat button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openChat(context),
              icon: const FaIcon(FontAwesomeIcons.comment, size: 16),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryColor,
                side: const BorderSide(color: AppColors.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Book button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _openBooking(context),
              icon: const FaIcon(FontAwesomeIcons.calendarCheck,
                  size: 16, color: Colors.white),
              label: const Text('Book Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Navigation actions ──────────────────────────────────────────────────

  void _openChat(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    // Generate a deterministic chat ID from the two user IDs
    final ids = [currentUid, handyman.id]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          chatId: chatId,
          otherUserId: handyman.id,
          otherUserName: handyman.name,
          otherUserPicture:
              handyman.image.isNotEmpty ? handyman.image : null,
        ),
      ),
    );
  }

  void _openBooking(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingScreen(
          handymanId: handyman.id,
          handymanName: handyman.name,
          hourlyRate: handyman.hourlyRate,
        ),
      ),
    );
  }
}

// ─── Review card used in the reviews list ──────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final ReviewModel review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating stars
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < review.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.star,
                  size: 18,
                );
              }),
              const SizedBox(width: 8),
              Text(
                review.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(review.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
            ],
          ),
          if (review.hasComment) ...[
            const SizedBox(height: 10),
            Text(
              review.comment!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textPrimaryColor(context),
                height: 1.4,
              ),
            ),
          ],
          if (review.hasResponse) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.reply, size: 16, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      review.handymanResponse!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

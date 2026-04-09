import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HandymanReviewsPage extends StatefulWidget {
  const HandymanReviewsPage({super.key});

  @override
  State<HandymanReviewsPage> createState() => _HandymanReviewsPageState();
}

class _HandymanReviewsPageState extends State<HandymanReviewsPage> {
  late final Stream<QuerySnapshot> _reviewsStream;
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _reviewsStream = FirebaseFirestore.instance
        .collection('reviews')
        .where('handymanId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        title: const Text(
          'My Reviews',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: AppColors.pagesAppBar(context),
        foregroundColor: AppColors.white,
        iconTheme: IconThemeData(color: AppColors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reviewsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.primaryColor),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading reviews',
                style: TextStyle(color: AppColors.textSecondaryColor(context)),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmpty();
          }

          // Summary header
          final ratings = docs
              .map((d) => (d['rating'] as num?)?.toDouble() ?? 0)
              .toList();
          final avg = ratings.reduce((a, b) => a + b) / ratings.length;

          return Column(
            children: [
              _buildSummary(avg, docs.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _buildReviewCard(data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummary(double avg, int total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryColor, AppColors.secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$total ${total == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data) {
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final comment = data['comment'] as String? ?? '';
    final clientName = data['clientName'] as String? ?? 'Client';
    final ts = data['createdAt'];
    final date = ts is Timestamp ? _formatDate(ts.toDate()) : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primaryColor.withValues(alpha: 0.15),
                child: Text(
                  clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_outline_rounded, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reviews from clients will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

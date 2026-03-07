import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/client/presentation/widgets/booking_dialog.dart';
import 'package:fixilya_app/services/favorites_service.dart';
import 'package:fixilya_app/services/reviews_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get/get.dart';

class HandymanDetailsPage extends StatefulWidget {
  final Map<String, dynamic> handyman;

  const HandymanDetailsPage({super.key, required this.handyman});

  @override
  State<HandymanDetailsPage> createState() => _HandymanDetailsPageState();
}

class _HandymanDetailsPageState extends State<HandymanDetailsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isFavorite = false;
  final ReviewsService _reviewsService = ReviewsService();
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoadingReviews = true;
  final FavoritesService _favoritesService = FavoritesService();
  List<String> _workImages = [];

  // Premium Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('🚀 Handyman Details Page Initialized for: ${widget.handyman}');
    _checkIfFavorite();
    _loadReviews();
    _loadWorkImages();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    if (kDebugMode) debugPrint('widget.handyman[reviews] ${widget.handyman['reviews']}');
    if (kDebugMode) debugPrint('widget.handyman ${widget.handyman}');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFavorite() async {
    final handymanId = widget.handyman['id'] ?? widget.handyman['uid'] ?? '';

    final isFav = await _favoritesService.isFavorite(handymanId);
    if (mounted) {
      setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _reviewsService.getHandymanReviews(
        widget.handyman['id'],
        limit: 2, // Show only 2 reviews initially
      );

      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading reviews: $e');
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  /// Load work images — uses the passed map first, then falls back to a
  /// direct Firestore fetch. This makes the portfolio section work correctly
  /// regardless of which navigation source (browse, map, favorites) opened
  /// this page, and regardless of cache state.
  Future<void> _loadWorkImages() async {
    final fromMap = widget.handyman['workImages'];
    if (fromMap is List && fromMap.isNotEmpty) {
      if (mounted) setState(() => _workImages = List<String>.from(fromMap));
      return;
    }

    final handymanId = widget.handyman['id'] ?? widget.handyman['uid'] ?? '';
    if (handymanId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('handymen')
          .doc(handymanId)
          .get();
      if (doc.exists && mounted) {
        final images = List<String>.from(doc.data()?['workImages'] ?? []);
        setState(() => _workImages = images);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading work images: $e');
    }
  }

  IconData _getSkillIcon(String skillName) {
    try {
      final skill = GlobalVariables.availableSkills.firstWhere(
        (s) => s['name'] == skillName,
        orElse: () => {'name': 'Unknown', 'icon': FontAwesomeIcons.wrench},
      );
      return skill['icon'] as IconData;
    } catch (e) {
      return FontAwesomeIcons.wrench;
    }
  }

  Future<void> _showAllReviewsDialog() async {
    // Fetch all reviews
    final allReviews = await _reviewsService.getHandymanReviews(
      widget.handyman['id'],
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.backgroundColor(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            SizedBox(height: 20),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, secondaryColor],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.rate_review,
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
                          'All Reviews',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimaryColor(context),
                          ),
                        ),
                        Text(
                          '${allReviews.length} total reviews',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondaryColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // Reviews List
            Expanded(
              child: allReviews.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No reviews yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      itemCount: allReviews.length,
                      itemBuilder: (context, index) {
                        final review = allReviews[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: _buildPremiumReviewCard(
                            name: review['clientName'],
                            rating: review['rating'],
                            date: _reviewsService.formatTimeAgo(
                              review['createdAt'],
                            ),
                            comment: review['comment'],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar with Parallax Effect
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.backgroundColor(context),
            leading: _buildGlassButton(
              icon: Icons.arrow_back,
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // _buildGlassButton(icon: Icons.share_outlined, onPressed: () {}),
              // SizedBox(width: 8),
              _buildGlassButton(
                icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                onPressed: () async {
                  final success = await _favoritesService.toggleFavorite(
                    widget.handyman['id'] ?? widget.handyman['uid'] ?? '',
                  );

                  if (success) {
                    setState(() => _isFavorite = !_isFavorite);

                    Get.snackbar(
                      _isFavorite ? '❤️ Added' : '💔 Removed',
                      _isFavorite
                          ? 'Added to favorites'
                          : 'Removed from favorites',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: _isFavorite ? Colors.green : Colors.grey,
                      colorText: Colors.white,
                      margin: EdgeInsets.all(16),
                      borderRadius: 12,
                      duration: Duration(seconds: 2),
                    );
                  }
                },
                iconColor: _isFavorite ? Colors.red : null,
              ),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero Image with Gradient Overlay
                  Hero(
                    tag: 'handyman_${widget.handyman['fullName']}',
                    child:
                        widget.handyman['profilePicture'] != null &&
                            widget.handyman['profilePicture'].isNotEmpty
                        ? Image.network(
                            widget.handyman['profilePicture'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // ✅ Show avatar if image fails to load
                              return _buildAvatarFallback();
                            },
                          )
                        : _buildAvatarFallback(), // ✅ Show avatar if no image
                  ),

                  // Premium Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.6),
                          Colors.black.withOpacity(0.85),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  // Handyman Info at Bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 30, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.handyman['fullName'] ??
                                      widget.handyman['name'] ??
                                      'Unnamed Handyman',

                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (widget.handyman['approved'] == true || widget.handyman['verified'] == true)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [primaryColor, secondaryColor],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withOpacity(0.4),
                                        blurRadius: 10,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verified Pro',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 0,
                              vertical: 6,
                            ),
                            // decoration: BoxDecoration(
                            //   color: Colors.white.withOpacity(0.2),
                            //   borderRadius: BorderRadius.circular(20),
                            //   border: Border.all(
                            //     color: Colors.white.withOpacity(0.3),
                            //     width: 1,
                            //   ),
                            // ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.workspace_premium,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 6),
                                      _buildSmartSkillsDisplay(), // ✅ USE THIS
                                    ],
                                  ),
                                ),
                                // Icon(
                                //   Icons.workspace_premium,
                                //   color: Colors.white,
                                //   size: 16,
                                // ),
                                // SizedBox(width: 6),
                                // Text(
                                //   widget.handyman['category'],
                                //   style: TextStyle(
                                //     color: Colors.white,
                                //     fontSize: 14,
                                //     fontWeight: FontWeight.w600,
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content with Animations
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 16),

                  // Premium Stats Cards with Glass Effect
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildPremiumStatCard(
                            icon: FontAwesomeIcons.solidStar,
                            iconColor: AppColors.reviews,
                            title: '${widget.handyman['rating']}',
                            subtitle: '${_reviews.length} reviews',
                            gradient: AppColors.reviewsCardGradientThemed(
                              context,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumStatCard(
                            icon: FontAwesomeIcons.briefcase,
                            iconColor: AppColors.jobs,
                            title: '${widget.handyman['completedJobs']}',
                            subtitle: 'Jobs Done',
                            gradient: AppColors.jobsDoneCardGradientThemed(
                              context,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildPremiumStatCard(
                            icon: FontAwesomeIcons.clock,
                            iconColor: AppColors.experience,
                            title: '${widget.handyman['experience'] ?? '—'}',
                            subtitle: 'Experience',
                            gradient: AppColors.experiencesCardGradientThemed(
                              context,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // SizedBox(height: 20),

                  // // Premium Price Card
                  // Padding(
                  //   padding: EdgeInsets.symmetric(horizontal: 16),
                  //   child: Container(
                  //     padding: EdgeInsets.all(20),
                  //     decoration: BoxDecoration(
                  //       gradient: LinearGradient(
                  //         begin: Alignment.topLeft,
                  //         end: Alignment.bottomRight,
                  //         colors: [
                  //           primaryColor.withOpacity(0.1),
                  //           secondaryColor.withOpacity(0.05),
                  //         ],
                  //       ),
                  //       borderRadius: BorderRadius.circular(20),
                  //       border: Border.all(
                  //         color: primaryColor.withOpacity(0.2),
                  //         width: 1.5,
                  //       ),
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: primaryColor.withOpacity(0.1),
                  //           blurRadius: 20,
                  //           offset: Offset(0, 10),
                  //         ),
                  //       ],
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         Container(
                  //           padding: EdgeInsets.all(14),
                  //           decoration: BoxDecoration(
                  //             gradient: LinearGradient(
                  //               colors: [primaryColor, secondaryColor],
                  //             ),
                  //             borderRadius: BorderRadius.circular(16),
                  //             boxShadow: [
                  //               BoxShadow(
                  //                 color: primaryColor.withOpacity(0.3),
                  //                 blurRadius: 15,
                  //                 offset: Offset(0, 5),
                  //               ),
                  //             ],
                  //           ),
                  //           child: FaIcon(
                  //             FontAwesomeIcons.wallet,
                  //             color: Colors.white,
                  //             size: 22,
                  //           ),
                  //         ),
                  //         SizedBox(width: 16),
                  //         Expanded(
                  //           child: Column(
                  //             crossAxisAlignment: CrossAxisAlignment.start,
                  //             children: [
                  //               Text(
                  //                 'Hourly Rate',
                  //                 style: TextStyle(
                  //                   fontSize: 13,
                  //                   color: Colors.grey[600],
                  //                   fontWeight: FontWeight.w500,
                  //                 ),
                  //               ),
                  //               SizedBox(height: 4),
                  //               Row(
                  //                 children: [
                  //                   Text(
                  //                     '${widget.handyman['hourlyRate']}',
                  //                     style: TextStyle(
                  //                       fontSize: 28,
                  //                       fontWeight: FontWeight.bold,
                  //                       color: primaryColor,
                  //                       height: 1,
                  //                     ),
                  //                   ),
                  //                   SizedBox(width: 6),
                  //                   Text(
                  //                     'DH/hour',
                  //                     style: TextStyle(
                  //                       fontSize: 14,
                  //                       color: Colors.grey[700],
                  //                       fontWeight: FontWeight.w600,
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //         Container(
                  //           padding: EdgeInsets.symmetric(
                  //             horizontal: 14,
                  //             vertical: 8,
                  //           ),
                  //           decoration: BoxDecoration(
                  //             color: Colors.green.withOpacity(0.1),
                  //             borderRadius: BorderRadius.circular(12),
                  //           ),
                  //           child: Row(
                  //             children: [
                  //               Icon(
                  //                 Icons.trending_down,
                  //                 color: Colors.green,
                  //                 size: 16,
                  //               ),
                  //               SizedBox(width: 4),
                  //               Text(
                  //                 'Fair',
                  //                 style: TextStyle(
                  //                   color: Colors.green,
                  //                   fontWeight: FontWeight.bold,
                  //                   fontSize: 12,
                  //                 ),
                  //               ),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  SizedBox(height: 24),

                  // Premium Contact Section
                  _buildSection(
                    'Contact Information',
                    Icons.contact_phone,
                    child: Column(
                      children: [
                        if (widget.handyman['showPhoneNumber'] == true)
                          _buildPremiumContactCard(
                            icon: FontAwesomeIcons.phone,
                            iconColor: AppColors.green,
                            title: 'Phone',
                            subtitle: widget.handyman['phone'] ?? '',
                            gradient: AppColors.handymanPhoneCardThemed(context),
                            onTap: () => _makePhoneCall(widget.handyman['phone'] ?? ''),
                          )
                        else
                          _buildPremiumContactCard(
                            icon: FontAwesomeIcons.lock,
                            iconColor: AppColors.textSecondaryColor(context),
                            title: 'Phone',
                            subtitle: 'Hidden by handyman',
                            gradient: AppColors.handymanPhoneCardThemed(context),
                            onTap: () {},
                          ),
                        SizedBox(height: 12),
                        _buildPremiumContactCard(
                          icon: FontAwesomeIcons.locationDot,
                          iconColor: AppColors.red,
                          title: 'Location',
                          subtitle: widget.handyman['city'],
                          gradient: AppColors.handymanLocationCardThemed(
                            context,
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Premium About Section
                  _buildSection(
                    'About Professional',
                    Icons.info_outline,
                    child: Container(
                      padding: EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.cardColor(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.borderColor(context),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLightColor(context),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.handyman['bio'] != ""
                            ? widget.handyman['bio']
                            : 'Premium ${((widget.handyman['category'] ?? (widget.handyman['skills'] as List?)?.firstOrNull ?? 'handyman')).toString().toLowerCase()} professional...',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: AppColors.textSecondaryColor(context),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Premium Services Section
                  _buildSection(
                    'Professional Services',
                    Icons.build_circle_outlined,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: widget.handyman['skills']
                          .map<Widget>(
                            (skill) => _buildPremiumServiceChip(
                              skill,
                              _getSkillIcon(
                                skill,
                              ), // ✅ Uses GlobalVariables.availableSkills
                            ),
                          )
                          .toList(),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Premium Portfolio Gallery
                  _buildSection(
                    'Portfolio Gallery',
                    Icons.photo_library_outlined,
                    child:
                        _workImages.isNotEmpty
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                ),
                            itemCount: _workImages.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () => _showImageDialog(
                                  context,
                                  _workImages[index],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    _workImages[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              primaryColor.withValues(
                                                alpha: 0.1,
                                              ),
                                              secondaryColor.withValues(
                                                alpha: 0.05,
                                              ),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.broken_image,
                                          color: AppColors.textSecondaryColor(
                                            context,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No portfolio images',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                  ),

                  SizedBox(height: 24),

                  // Premium Reviews Section
                  _buildSection(
                    'Client Reviews',
                    Icons.rate_review_outlined,
                    child: _isLoadingReviews
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : _reviews.isEmpty
                        ? Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.inputFillColor(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                'No reviews yet',
                                style: TextStyle(
                                  color: AppColors.textSecondaryColor(context),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Show first 2 reviews
                              ..._reviews.map(
                                (review) => Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: _buildPremiumReviewCard(
                                    name: review['clientName'],
                                    rating: review['rating'],
                                    date: _reviewsService.formatTimeAgo(
                                      review['createdAt'],
                                    ),
                                    comment: review['comment'],
                                  ),
                                ),
                              ),

                              // View All Reviews Button
                              SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () =>
                                      _showAllReviewsDialog(), // ✅ NEW METHOD
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryColor,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'View All Reviews',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward, size: 16),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // Premium Floating Bottom Bar
      bottomNavigationBar: Container(
        margin: EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor(
                  context,
                ).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderColor(context).withValues(alpha: 0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Call Button
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.handyman['showPhoneNumber'] == true
                              ? () => _makePhoneCall(widget.handyman['phone'] ?? '')
                              : () => Get.snackbar(
                                    'Phone Hidden',
                                    'This handyman has not shared their phone number yet',
                                    snackPosition: SnackPosition.BOTTOM,
                                    margin: EdgeInsets.all(16),
                                    borderRadius: 12,
                                    duration: Duration(seconds: 2),
                                  ),
                          borderRadius: BorderRadius.circular(16),
                          child: Center(
                            child: FaIcon(
                              widget.handyman['showPhoneNumber'] == true
                                  ? FontAwesomeIcons.phone
                                  : FontAwesomeIcons.lock,
                              color: widget.handyman['showPhoneNumber'] == true
                                  ? AppColors.primaryColor
                                  : AppColors.textSecondaryColor(context),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Book Now Button
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryColor,
                              AppColors.secondaryColor,
                              AppColors.accentColor,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                showBookingDialog(context, widget.handyman),
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FaIcon(
                                    FontAwesomeIcons.calendarCheck,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Book Appointment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor(context).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(icon, color: iconColor ?? Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: FaIcon(icon, color: iconColor, size: 18),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryColor(context),
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryColor(context),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, {required Widget child}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, secondaryColor],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.white, size: 18),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPremiumContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: FaIcon(icon, color: iconColor, size: 20),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              // Container(
              //   padding: EdgeInsets.all(8),
              //   decoration: BoxDecoration(
              //     color: Colors.white.withOpacity(0.7),
              //     borderRadius: BorderRadius.circular(10),
              //   ),
              //   child: Icon(
              //     Icons.arrow_forward_ios,
              //     size: 16,
              //     color: iconColor,
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumServiceChip(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(0.12),
            secondaryColor.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumReviewCard({
    required String name,
    required int rating,
    required String date,
    required String comment,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLightColor(context),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    name[0],
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
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
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Color.fromARGB(
                      91,
                      255,
                      183,
                      0,
                    ).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Color(0xFFFFB800), size: 14),
                    SizedBox(width: 4),
                    Text(
                      '$rating.0',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFFFF8F00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            comment,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondaryColor(context),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartSkillsDisplay() {
    final skills = widget.handyman['skills'] as List<dynamic>? ?? [];

    if (skills.isEmpty) {
      return Text(
        'General Services',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (skills.length == 1) {
      // Show single skill
      return Text(
        skills[0],
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    if (skills.length == 2) {
      // Show both skills
      return Text(
        '${skills[0]}, ${skills[1]}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Show first 2 skills + "..." button
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '${skills[0]}, ${skills[1]}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 6),
        GestureDetector(
          onTap: () => _showAllSkillsPopup(),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarFallback() {
    // Get first letter of name
    String initial =
        widget.handyman['name'] ?? widget.handyman['fullName'] ?? '';
    initial = initial.isNotEmpty ? initial[0].toUpperCase() : 'H';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, secondaryColor, accentColor],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.bold,
            color: Colors.white.withOpacity(0.9),
            shadows: [
              Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ ADD THIS METHOD FOR POPUP
  void _showAllSkillsPopup() {
    final skills = widget.handyman['skills'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.build, color: primaryColor),
            SizedBox(width: 12),
            Text('All Skills'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: skills.map<Widget>((skill) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(_getSkillIcon(skill), size: 18, color: primaryColor),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(skill, style: TextStyle(fontSize: 15)),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  icon: Icons.close,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: EdgeInsets.all(40),
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // void _showBookingDialog(BuildContext context) {
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => Container(
  //       height: MediaQuery.of(context).size.height * 0.7,
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
  //       ),
  //       child: Column(
  //         children: [
  //           SizedBox(height: 12),
  //           Container(
  //             width: 50,
  //             height: 5,
  //             decoration: BoxDecoration(
  //               color: Colors.grey[300],
  //               borderRadius: BorderRadius.circular(10),
  //             ),
  //           ),
  //           SizedBox(height: 20),
  //           Padding(
  //             padding: EdgeInsets.symmetric(horizontal: 24),
  //             child: Row(
  //               children: [
  //                 Container(
  //                   padding: EdgeInsets.all(12),
  //                   decoration: BoxDecoration(
  //                     gradient: LinearGradient(
  //                       colors: [primaryColor, secondaryColor],
  //                     ),
  //                     borderRadius: BorderRadius.circular(14),
  //                     boxShadow: [
  //                       BoxShadow(
  //                         color: primaryColor.withOpacity(0.3),
  //                         blurRadius: 12,
  //                         offset: Offset(0, 4),
  //                       ),
  //                     ],
  //                   ),
  //                   child: Icon(
  //                     Icons.calendar_month,
  //                     color: Colors.white,
  //                     size: 24,
  //                   ),
  //                 ),
  //                 SizedBox(width: 16),
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'Book Appointment',
  //                         style: TextStyle(
  //                           fontSize: 22,
  //                           fontWeight: FontWeight.bold,
  //                           color: Colors.black87,
  //                         ),
  //                       ),
  //                       Text(
  //                         'with ${widget.handyman['name']}',
  //                         style: TextStyle(
  //                           fontSize: 14,
  //                           color: Colors.grey[600],
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           SizedBox(height: 24),
  //           Expanded(
  //             child: SingleChildScrollView(
  //               padding: EdgeInsets.symmetric(horizontal: 24),
  //               child: Column(
  //                 children: [
  //                   _buildPremiumTextField(
  //                     label: 'Your Name',
  //                     icon: Icons.person_outline,
  //                   ),
  //                   SizedBox(height: 16),
  //                   _buildPremiumTextField(
  //                     label: 'Phone Number',
  //                     icon: Icons.phone_outlined,
  //                   ),
  //                   SizedBox(height: 16),
  //                   _buildPremiumTextField(
  //                     label: 'Preferred Date',
  //                     icon: Icons.calendar_today_outlined,
  //                     readOnly: true,
  //                     onTap: () async {
  //                       await showDatePicker(
  //                         context: context,
  //                         initialDate: DateTime.now(),
  //                         firstDate: DateTime.now(),
  //                         lastDate: DateTime.now().add(Duration(days: 365)),
  //                       );
  //                     },
  //                   ),
  //                   SizedBox(height: 16),
  //                   _buildPremiumTextField(
  //                     label: 'Describe your requirements',
  //                     icon: Icons.description_outlined,
  //                     maxLines: 4,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //           Padding(
  //             padding: EdgeInsets.all(24),
  //             child: Container(
  //               width: double.infinity,
  //               height: 56,
  //               decoration: BoxDecoration(
  //                 gradient: LinearGradient(
  //                   colors: [primaryColor, secondaryColor, accentColor],
  //                 ),
  //                 borderRadius: BorderRadius.circular(16),
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: primaryColor.withOpacity(0.4),
  //                     blurRadius: 20,
  //                     offset: Offset(0, 8),
  //                   ),
  //                 ],
  //               ),
  //               child: Material(
  //                 color: Colors.transparent,
  //                 child: InkWell(
  //                   onTap: () {
  //                     Navigator.pop(context);
  //                     ScaffoldMessenger.of(context).showSnackBar(
  //                       SnackBar(
  //                         content: Row(
  //                           children: [
  //                             Icon(Icons.check_circle, color: Colors.white),
  //                             SizedBox(width: 12),
  //                             Text('Booking request sent successfully!'),
  //                           ],
  //                         ),
  //                         backgroundColor: primaryColor,
  //                         behavior: SnackBarBehavior.floating,
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(12),
  //                         ),
  //                       ),
  //                     );
  //                   },
  //                   borderRadius: BorderRadius.circular(16),
  //                   child: Center(
  //                     child: Text(
  //                       'Confirm Booking',
  //                       style: TextStyle(
  //                         fontSize: 17,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.white,
  //                         letterSpacing: 0.5,
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildPremiumTextField({
  //   required String label,
  //   required IconData icon,
  //   int maxLines = 1,
  //   bool readOnly = false,
  //   VoidCallback? onTap,
  // }) {
  //   return TextField(
  //     maxLines: maxLines,
  //     readOnly: readOnly,
  //     onTap: onTap,
  //     decoration: InputDecoration(
  //       labelText: label,
  //       labelStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
  //       prefixIcon: Container(
  //         margin: EdgeInsets.all(12),
  //         padding: EdgeInsets.all(8),
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             colors: [
  //               primaryColor.withOpacity(0.1),
  //               secondaryColor.withOpacity(0.05),
  //             ],
  //           ),
  //           borderRadius: BorderRadius.circular(10),
  //         ),
  //         child: Icon(icon, size: 20, color: primaryColor),
  //       ),
  //       filled: true,
  //       fillColor: Colors.grey[50],
  //       border: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: BorderSide.none,
  //       ),
  //       enabledBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
  //       ),
  //       focusedBorder: OutlineInputBorder(
  //         borderRadius: BorderRadius.circular(14),
  //         borderSide: BorderSide(color: primaryColor, width: 2),
  //       ),
  //       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  //     ),
  //   );
  // }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }
}

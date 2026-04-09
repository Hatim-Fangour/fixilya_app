import 'package:flutter/foundation.dart';
// lib/features/guest/presentation/pages/guest_home_page.dart
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/handyman_card.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:fixilya_app/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
  final HandymanApiService _handymanService = HandymanApiService();
  List<Map<String, dynamic>> _allHandymen = [];
  final String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHandymen();
  }

  Future<void> _loadHandymen() async {
    try {
      final handymen = await _handymanService.getAllHandymen();

      if (mounted) {
        setState(() {
          _allHandymen = handymen;
          _isLoading = false;
        });

        if (kDebugMode) debugPrint('✅ Loaded ${_allHandymen.length} handymen (Guest Mode)');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading handymen: $e');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> get filteredJobs {
    return _allHandymen.where((job) {
      final cityMatch =
          GlobalVariables.selectedCity == 'All Cities' ||
          job['city'] == GlobalVariables.selectedCity;

      bool categoryMatch = GlobalVariables.selectedCategory == 'All Services';
      if (!categoryMatch && job['skills'] is List) {
        final skills = job['skills'] as List;
        categoryMatch = skills.contains(GlobalVariables.selectedCategory);
      }

      bool searchMatch = _searchQuery.isEmpty;
      if (!searchMatch) {
        final name = job['name'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        searchMatch = name.contains(query);
      }

      return cityMatch && categoryMatch && searchMatch;
    }).toList();
  }

  void _showLoginPrompt(String action) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryColor, AppColors.secondaryColor],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, color: Colors.white, size: 40),
              ),
              SizedBox(height: 20),
              Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'You need to login to $action',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryColor(context),
                ),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: AppColors.grey300),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        Get.toNamed(AppRoutes.login);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header with Guest Banner
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Guest Mode Banner
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Browsing as Guest',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Container(
                  //   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  //   decoration: BoxDecoration(
                  //     color: Colors.orange.withValues(alpha: 0.9),
                  //     borderRadius: BorderRadius.circular(20),
                  //   ),
                  //   child: Obx(() {
                  //     final themeController = Get.find<ThemeController>();
                  //     return Row(
                  //       mainAxisSize: MainAxisSize.min,
                  //       children: [
                  //         Icon(
                  //           Icons.visibility_outlined,
                  //           color: Colors.white,
                  //           size: 16,
                  //         ),
                  //         SizedBox(width: 6),
                  //         Text(
                  //           'Guest Mode • ${themeController.getThemePreferenceName()}',
                  //           style: TextStyle(
                  //             fontSize: 12,
                  //             fontWeight: FontWeight.w600,
                  //             color: Colors.white,
                  //           ),
                  //         ),
                  //       ],
                  //     );
                  //   }),
                  // ),
                  SizedBox(height: 12),

                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Handyman',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Explore professional services',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Container(
                          //   margin: EdgeInsets.only(right: 8),
                          //   decoration: BoxDecoration(
                          //     color: Colors.purple.withValues(alpha: 0.9),
                          //     borderRadius: BorderRadius.circular(10),
                          //   ),
                          //   child: IconButton(
                          //     icon: Icon(
                          //       Icons.bug_report,
                          //       color: Colors.white,
                          //       size: 18,
                          //     ),
                          //     onPressed: () {
                          //       final themeController =
                          //           Get.find<ThemeController>();
                          //       print(
                          //         'Current theme: ${themeController.getThemePreferenceName()}',
                          //       );
                          //       print(
                          //         'System brightness: ${themeController.systemBrightness}',
                          //       );
                          //       print(
                          //         'Is dark mode: ${themeController.isDarkMode}',
                          //       );
                          //       print(
                          //         'Theme mode: ${themeController.themeMode}',
                          //       );

                          //       Get.snackbar(
                          //         'Theme Debug',
                          //         'Theme: ${themeController.getThemePreferenceName()}\n'
                          //             'System: ${themeController.systemBrightness}\n'
                          //             'Dark: ${themeController.isDarkMode}',
                          //         backgroundColor: Colors.purple,
                          //         colorText: Colors.white,
                          //       );
                          //     },
                          //     padding: EdgeInsets.all(8),
                          //     constraints: BoxConstraints(),
                          //     tooltip: 'Debug Theme',
                          //   ),
                          // ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor(
                                context,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.rightToBracket,
                                color: AppColors.white,
                                size: 18,
                              ),
                              onPressed: () => Get.toNamed(AppRoutes.login),
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                              tooltip: 'Login',
                            ),
                          ),
                          // Container(
                          //   margin: EdgeInsets.only(right: 8),
                          //   decoration: BoxDecoration(
                          //     color: Colors.red.withValues(alpha: 0.9),
                          //     borderRadius: BorderRadius.circular(10),
                          //   ),
                          //   child: IconButton(
                          //     icon: Icon(
                          //       Icons.refresh,
                          //       color: Colors.white,
                          //       size: 18,
                          //     ),
                          //     onPressed: () async {
                          //       final localStorage = LocalStorageService();
                          //       await localStorage.setThemePreference('system');

                          //       final themeController =
                          //           Get.find<ThemeController>();
                          //       await themeController.resetThemeToSystem();

                          //       Get.snackbar(
                          //         'Theme Reset',
                          //         'Cleared all theme preferences. Theme reset to system.',
                          //         backgroundColor: Colors.green,
                          //         colorText: Colors.white,
                          //       );

                          //       // Force reload the page
                          //       Get.offAll(() => GuestHomePage());
                          //     },
                          //     padding: EdgeInsets.all(8),
                          //     constraints: BoxConstraints(),
                          //     tooltip: 'Reset Theme',
                          //   ),
                          // ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search for services...',
                        hintStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filters Section (same as client home)
            Container(
              // color: AppColors.white,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            GlobalVariables.selectedCity = 'All Cities';
                            GlobalVariables.selectedCategory = 'All Services';
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      // City Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'City',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.borderColor(context),
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: GlobalVariables.selectedCity,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: GlobalVariables.cities.map((city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(city),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    GlobalVariables.selectedCity = newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10),

                      // Service Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.borderColor(context),
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: GlobalVariables.selectedCategory,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: GlobalVariables.availableSkills.map((
                                  category,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: category['name'],
                                    child: Row(
                                      children: [
                                        FaIcon(
                                          category['icon'],
                                          size: 12,
                                          color: AppColors.primaryColor,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            category['name'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    GlobalVariables.selectedCategory =
                                        newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.dividerColor(context),
            ),

            // Results Count
            Container(
              // color: AppColors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${filteredJobs.length} Available',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimaryColor(context),
                    ),
                  ),
                ],
              ),
            ),

            // Jobs List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                    )
                  : filteredJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.magnifyingGlass,
                            size: 48,
                            color: AppColors.grey400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No handymen found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey500,
                            ),
                          ),
                          SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Get.toNamed(AppRoutes.login),
                            icon: Icon(Icons.login),
                            label: Text(
                              'Login to Book Services',
                              style: TextStyle(color: AppColors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: filteredJobs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _showLoginPrompt('view full details'),
                            child: Stack(
                              children: [
                                HandymanCard(job: filteredJobs[index]),
                                // Overlay to indicate guest mode
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: Colors.black.withValues(
                                        alpha: 0.02,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      // Floating Action Button to prompt login
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.login),
        backgroundColor: AppColors.primaryColor,
        icon: Icon(Icons.login, color: Colors.white),
        label: Text(
          'Login to Book',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}

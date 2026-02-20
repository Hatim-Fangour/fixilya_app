import 'package:fixilya_app/core/constants/app_assets.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/data/notifiers.dart';
import 'package:fixilya_app/features/client/presentation/screens/client_profile_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_profile_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_home_page.dart';

import 'package:fixilya_app/features/client/presentation/screens/client_home_page.dart';
import 'package:fixilya_app/shared/widgets/navbar_widget.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fixilya_app/l10n/app_localizations.dart';

class WidgetTree extends StatefulWidget {
  const WidgetTree({super.key});

  @override
  State<WidgetTree> createState() => _WidgetTreeState();
}

class _WidgetTreeState extends State<WidgetTree> {
  // Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);

  final _authService = AuthService();
  String _userType = 'handyman'; // Default
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ Reset to home page when widget initializes
    // ✅ Defer until after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      selectedPageNotifier.value = 0;
    });
    _loadUserType();
  }

  Future<void> _loadUserType() async {
    try {
      // Get user type from AuthService or Firebase
      final userType = await _authService.getUserType();

      setState(() {
        _userType = userType?.toLowerCase() ?? 'handyman';
        _isLoading = false;
      });

      // ✅ Reset to home after loading user type
      selectedPageNotifier.value = 0;

      print('✅ User type loaded: $_userType');
    } catch (e) {
      print('❌ Error loading user type: $e');
      setState(() {
        _userType = 'handyman'; // Fallback
        _isLoading = false;
      });

      // ✅ Reset to home on error
      selectedPageNotifier.value = 0;
    }
  }

  // ✅ Dynamic pages based on user type
  List<Widget> get _pages {
    if (_userType == 'client') {
      return [ClientHomePage(), ClientProfilePage()];
    } else {
      return [HandymanHomePage(), HandymanProfilePage()];
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final themeController = Get.find<ThemeController>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.appHeaderGradientThemed(context),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
            title: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceColor(
                      context,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    AppAssets.logoLight,
                    width: 35,
                    height: 35,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Welcome to Fixilya',
                  // l10n.welcome,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),

            // actions: [
            //   Container(
            //     margin: EdgeInsets.only(right: 8),
            //     decoration: BoxDecoration(
            //       color: AppColors.surfaceColor(context).withValues(alpha: 0.2),
            //       borderRadius: BorderRadius.circular(10),
            //     ),
            //     child: IconButton(
            //       onPressed: () {
            //         themeController.toggleTheme();
            //       },
            //       icon: Obx(
            //         () => Icon(
            //           themeController.isDarkMode
            //               ? Icons.light_mode_outlined
            //               : Icons.dark_mode_outlined,
            //           color: Colors.white,
            //           size: 20,
            //         ),
            //       ),
            //       padding: EdgeInsets.all(8),
            //       constraints: BoxConstraints(),
            //     ),
            //   ),
            // ],
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: selectedPageNotifier,
        builder: (BuildContext context, dynamic selectedPage, Widget? child) {
          // ✅ CRITICAL FIX: Safe index validation
          final safeIndex =
              selectedPage is int &&
                  selectedPage >= 0 &&
                  selectedPage < _pages.length
              ? selectedPage
              : 0; // Default to home if invalid

          // ✅ Update notifier if index was invalid
          if (safeIndex != selectedPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              selectedPageNotifier.value = safeIndex;
            });
          }

          return _pages.elementAt(safeIndex);
        },
      ),
      bottomNavigationBar: NavBarWidget(userType: _userType),
    );
  }
}

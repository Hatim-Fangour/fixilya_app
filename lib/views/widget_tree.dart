import 'package:fixilya_app/core/constants/app_assets.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/data/notifiers.dart';
import 'package:fixilya_app/features/client/presentation/screens/client_profile_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_profile_page.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/handyman_home_page.dart';
import 'package:fixilya_app/features/marketplace/presentation/screens/marketplace_page.dart';

import 'package:fixilya_app/features/client/presentation/screens/client_home_page.dart';
import 'package:fixilya_app/shared/widgets/navbar_widget.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/data_persistence_service.dart';
import 'package:fixilya_app/services/location_service.dart';
import 'package:flutter/foundation.dart';
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
  final _cache = DataPersistenceService();
  String? _userType; // null until resolved -- prevents wrong-screen flash
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
      // 1. Try cached user type first for instant display (no loading spinner)
      final cachedType = _cache.getCachedString(
        DataPersistenceService.keyUserType,
        ttl: const Duration(days: 30),
      );

      if (cachedType != null && cachedType.isNotEmpty) {
        if (kDebugMode) debugPrint('WidgetTree: instant display from cached userType: $cachedType');
        if (mounted) {
          setState(() {
            _userType = cachedType.toLowerCase();
            _isLoading = false;
          });
          selectedPageNotifier.value = 0;
        }
      }

      // 2. Always fetch from network to confirm / update
      final userType = await _authService.getUserType();
      if (!mounted) return;

      if (userType == null || userType.isEmpty) {
        if (kDebugMode) debugPrint('WidgetTree: userType is null -- defaulting to client');
        // Only show snackbar if we had no cached data
        if (cachedType == null) {
          Get.snackbar(
            'Profile Issue',
            'Could not determine your account type. Showing client view.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 16,
            duration: const Duration(seconds: 3),
          );
        }
      }

      final resolvedType = (userType ?? 'client').toLowerCase();

      // 3. Cache the resolved user type for next app start
      await _cache.cacheString(DataPersistenceService.keyUserType, resolvedType);

      // 4. Update UI if type changed or still loading
      if (_userType != resolvedType || _isLoading) {
        setState(() {
          _userType = resolvedType;
          _isLoading = false;
          _cachedPages = null; // force page list to rebuild for new user type
        });
        selectedPageNotifier.value = 0;
      }

      // Capture GPS on every app open for both user types
      final locService = LocationService();
      locService.getCurrentLocation().then((pos) {
        if (pos == null) return;
        if (_userType == 'handyman') {
          locService.saveHandymanLocation(pos);
        } else {
          locService.saveClientLocation(pos);
        }
      }).catchError((e) {
        if (kDebugMode) debugPrint('WidgetTree: background GPS capture failed: $e');
      });
    } catch (e) {
      if (kDebugMode) debugPrint('WidgetTree: _loadUserType error: $e');
      if (!mounted) return;

      // Fall back to cached type if available, otherwise default to client
      final fallbackType = _cache.getCachedDataStale<String>(
            DataPersistenceService.keyUserType,
          ) ??
          'client';

      setState(() {
        _userType = fallbackType;
        _isLoading = false;
      });
      selectedPageNotifier.value = 0;

      // Only show error if we truly have no data
      if (_cache.getCachedDataStale<String>(DataPersistenceService.keyUserType) == null) {
        Get.snackbar(
          'Error',
          'Could not load your profile. Please try logging in again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 16,
        );
      }
    }
  }

  // ── Page cache ────────────────────────────────────────────────────────────
  // Stored as a field so the same widget instances are reused across tab
  // switches. Re-created only when _userType changes (e.g. after a re-login).
  //
  // WHY: `_pages` was a getter that returned NEW instances on every call.
  // When used with ValueListenableBuilder, Flutter destroyed the old page and
  // rebuilt a fresh one on every tap — triggering onInit(), Firestore queries,
  // and full widget-tree construction each time. That caused ~10-second delays.
  //
  // With IndexedStack + a cached list, pages are built once and simply
  // shown/hidden on tab switch → instant navigation.
  List<Widget>? _cachedPages;

  List<Widget> get _pages {
    if (_cachedPages != null) return _cachedPages!;
    if (_userType == 'handyman') {
      _cachedPages = [
        const HandymanHomePage(),
        const MarketplacePage(),
        HandymanProfilePage(),
      ];
    } else {
      // client and admin both use the client layout as a fallback
      // (admins should be routed to /admin directly and not reach WidgetTree)
      _cachedPages = [
        const ClientHomePage(),
        const MarketplacePage(),
        ClientProfilePage(),
      ];
    }
    return _cachedPages!;
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
          final safeIndex =
              selectedPage is int &&
                  selectedPage >= 0 &&
                  selectedPage < _pages.length
              ? selectedPage
              : 0;

          // Correct an out-of-range notifier value without causing a build-phase setState.
          if (safeIndex != selectedPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              selectedPageNotifier.value = safeIndex;
            });
          }

          // IndexedStack keeps every page alive in the widget tree and simply
          // shows/hides them. No widget is destroyed or re-created on tab switch,
          // so onInit() and data-fetch calls run exactly once per session.
          return IndexedStack(
            index: safeIndex,
            children: _pages,
          );
        },
      ),
      bottomNavigationBar: NavBarWidget(userType: _userType ?? 'client'),
    );
  }
}

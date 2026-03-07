import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/services/auth_service.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/location_privacy_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/services/language_service.dart';
import 'package:fixilya_app/services/settings_backend_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class HandymanSettingsPage extends StatefulWidget {
  const HandymanSettingsPage({super.key});

  @override
  State<HandymanSettingsPage> createState() => _HandymanSettingsPageState();
}

class _HandymanSettingsPageState extends State<HandymanSettingsPage>
    with SingleTickerProviderStateMixin {
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  final _settingsBackendService = SettingsBackendService();
  final _authService = AuthService();
  final _locationPrivacyService = LocationPrivacyService();

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  // Notification toggles
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = true;

  // Location privacy
  String _locationPrivacy = 'city_only';

  // Phone privacy
  bool _showPhoneNumber = false;

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadSettings();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // DATA
  // ─────────────────────────────────────────────

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final results = await Future.wait([
        _settingsBackendService.getHandymanSettings(),
        if (uid != null)
          _locationPrivacyService.getHandymanPrivacy(uid)
        else
          Future.value('city_only'),
      ]);

      final data = results[0] as Map<String, dynamic>?;
      final privacy = results[1] as String;

      if (data != null && mounted) {
        setState(() {
          _profileData = data;
          _pushNotifications = data['pushNotifications'] ?? true;
          _emailNotifications = data['emailNotifications'] ?? false;
          _smsNotifications = data['smsNotifications'] ?? true;
          _showPhoneNumber = data['showPhoneNumber'] ?? false;
          _locationPrivacy = privacy;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading settings: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSettings(Map<String, dynamic> updates) async {
    try {
      await _settingsBackendService.updateHandymanSettings(updates);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update settings',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
      );
    }
  }

  Future<void> _updateProfileInfo(Map<String, dynamic> updates) async {
    final success = await _settingsBackendService.updateProfileInfo(updates);
    if (success) {
      await _loadSettings();
      Get.snackbar(
        'Success',
        'Profile updated successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 16,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 2),
      );
    } else {
      throw Exception('Update failed');
    }
  }

  /// Copies an [XFile] into the system temp directory.
  /// Works for both `file://` paths and Android `content://` URIs.
  Future<File> _xFileToTempFile(XFile xFile) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = xFile.name.isNotEmpty
        ? xFile.name
        : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final tempFile = File('${tempDir.path}/$fileName');
    final Uint8List bytes = await xFile.readAsBytes();
    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile;
  }

  Future<void> _changeProfilePicture() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      // Show uploading indicator
      Get.dialog(
        Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Uploading...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // ✅ FIX: convert XFile → real temp File (handles Android content:// URIs)
      final File tempFile = await _xFileToTempFile(picked);

      final cloudinaryService = Get.find<CloudinaryService>();
      final String? imageUrl = await cloudinaryService.uploadImage(
        imageFile: tempFile,
        folder: 'profiles',
        isProfilePicture: true,
      );

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}

      // Close loading dialog
      if (Get.isDialogOpen ?? false) Get.back();

      if (imageUrl != null && imageUrl.isNotEmpty) {
        final String? savedUrl = await _settingsBackendService
            .updateProfilePicture(imageUrl);

        if (savedUrl != null) {
          await _loadSettings();
          Get.snackbar(
            'Success',
            'Profile picture updated!',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 16,
            icon: const Icon(Icons.check_circle, color: Colors.white),
          );
        }
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      if (kDebugMode) debugPrint('❌ Error changing profile picture: $e');
      Get.snackbar(
        'Error',
        'Failed to upload image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        borderRadius: 16,
        margin: const EdgeInsets.all(16),
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor, accentColor],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
                SizedBox(height: 24),
                Text(
                  'Loading Settings...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildLuxuryAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildThemeSection(),
                  const SizedBox(height: 24),
                  _buildLuxurySection(
                    'Notifications',
                    Icons.notifications_active_outlined,
                    [
                      _buildLuxurySwitchTile(
                        'Push Notifications',
                        'Receive instant updates',
                        Icons.notifications_rounded,
                        _pushNotifications,
                        (value) {
                          setState(() => _pushNotifications = value);
                          _updateSettings({'pushNotifications': value});
                        },
                      ),
                      _buildLuxurySwitchTile(
                        'Email Notifications',
                        'Get updates via email',
                        Icons.email_outlined,
                        _emailNotifications,
                        (value) {
                          setState(() => _emailNotifications = value);
                          _updateSettings({'emailNotifications': value});
                        },
                      ),
                      _buildLuxurySwitchTile(
                        'SMS Notifications',
                        'Receive text alerts',
                        Icons.message_outlined,
                        _smsNotifications,
                        (value) {
                          setState(() => _smsNotifications = value);
                          _updateSettings({'smsNotifications': value});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLuxurySection(
                    'Privacy',
                    Icons.lock_outline_rounded,
                    [
                      _buildLuxurySwitchTile(
                        'Show Phone Number',
                        _showPhoneNumber
                            ? 'Clients with confirmed bookings can see your phone'
                            : 'Your phone number is hidden from clients',
                        Icons.phone_outlined,
                        _showPhoneNumber,
                        (value) {
                          setState(() => _showPhoneNumber = value);
                          _updateSettings({'showPhoneNumber': value});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLocationPrivacySection(),
                  const SizedBox(height: 24),
                  _buildLuxurySection('Account', Icons.person_outline_rounded, [
                    // _buildLuxuryListTile(
                    //   'Edit Profile Information',
                    //   'Update your personal details',
                    //   Icons.edit_outlined,
                    //   () => _showEditProfileDialog(),
                    // ),
                    _buildLuxuryListTile(
                      'Change Profile Picture',
                      'Upload a new photo',
                      Icons.camera_alt_outlined,
                      () => _changeProfilePicture(),
                    ),
                    _buildLuxuryListTile(
                      'Change Password',
                      'Update your security',
                      Icons.lock_outline_rounded,
                      () => _showChangePasswordDialog(),
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildLuxurySection(
                    'Support & Legal',
                    Icons.support_agent_outlined,
                    [
                      _buildLuxuryListTile(
                        'Help & Support',
                        'Get assistance',
                        Icons.help_outline_rounded,
                        () => _showHelpSupport(),
                      ),
                      _buildLuxuryListTile(
                        'Terms & Conditions',
                        'Read our terms',
                        Icons.description_outlined,
                        () => _showTerms(),
                      ),
                      _buildLuxuryListTile(
                        'Privacy Policy',
                        'Your data protection',
                        Icons.policy_outlined,
                        () => _showPrivacyPolicy(),
                        isLast: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildLuxurySection(
                    'Danger Zone',
                    Icons.warning_amber_rounded,
                    [
                      _buildLuxuryListTile(
                        'Delete Account',
                        'Permanently remove your account',
                        Icons.delete_forever_outlined,
                        () => _showDeleteAccountDialog(),
                        isDestructive: true,
                      ),
                      _buildLuxuryListTile(
                        'Logout',
                        'Sign out from your account',
                        Icons.logout_rounded,
                        () => _showLogoutDialog(),
                        isDestructive: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WIDGETS
  // ─────────────────────────────────────────────

  Widget _buildLuxuryAppBar() {
    final profilePicture = _profileData?['profilePicture'] ?? '';
    final fullName = _profileData?['fullName'] ?? 'Handyman';
    final email = _profileData?['email'] ?? '';

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.pagesAppBar(context),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _CirclePatternPainter()),
            ),
            Positioned.fill(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) => Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.5),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.shadowColor(
                                    context,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: profilePicture.isNotEmpty
                                  ? NetworkImage(profilePicture)
                                  : null,
                              onBackgroundImageError: profilePicture.isNotEmpty
                                  ? (_, __) {}
                                  : null,
                              child: profilePicture.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: primaryColor,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        fullName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                email,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxurySection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.dividerColor(context),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor(context).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxurySwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.dividerColor(context), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.15),
                  secondaryColor.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryColor(context),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.9,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: primaryColor,
              activeTrackColor: primaryColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuxuryListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.dividerColor(context),
                      width: 1,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDestructive
                        ? [
                            Colors.red.withValues(alpha: 0.15),
                            Colors.red.withValues(alpha: 0.1),
                          ]
                        : [
                            primaryColor.withValues(alpha: 0.15),
                            secondaryColor.withValues(alpha: 0.1),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red : primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive
                            ? AppColors.red
                            : AppColors.textPrimaryColor(context),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationPrivacySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Location Privacy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.dividerColor(context),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor(context).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildPrivacyRadioTile(
                  value: 'city_only',
                  title: 'Show only my city',
                  subtitle: 'Clients see your city centre on the map',
                  isRecommended: true,
                  isLast: false,
                ),
                _buildPrivacyRadioTile(
                  value: 'exact',
                  title: 'Show my exact location',
                  subtitle: 'Your GPS coordinates are visible on the map',
                  isRecommended: false,
                  isLast: false,
                ),
                _buildPrivacyRadioTile(
                  value: 'on_booking_accept',
                  title: 'Only share when I accept a booking',
                  subtitle: 'You won\'t appear on the map until you confirm',
                  isRecommended: false,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyRadioTile({
    required String value,
    required String title,
    required String subtitle,
    required bool isRecommended,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.dividerColor(context),
                  width: 1,
                ),
              ),
      ),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: _locationPrivacy,
            activeColor: primaryColor,
            onChanged: (selected) async {
              if (selected == null) return;
              setState(() => _locationPrivacy = selected);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                try {
                  await _locationPrivacyService.setHandymanPrivacy(
                    uid,
                    selected,
                  );
                } catch (_) {
                  Get.snackbar(
                    'Error',
                    'Failed to save privacy setting',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 16,
                  );
                }
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                    if (isRecommended) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    final themeController = Get.find<ThemeController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.secondaryColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Appearance',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardColor(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.borderColor(context),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColor(context).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildThemeOption(
                  title: 'Light Mode',
                  subtitle: 'Classic bright theme',
                  icon: Icons.light_mode_outlined,
                  value: ThemePreference.light,
                  themeController: themeController,
                ),
                _buildThemeOption(
                  title: 'Dark Mode',
                  subtitle: 'Easy on the eyes',
                  icon: Icons.dark_mode_outlined,
                  value: ThemePreference.dark,
                  themeController: themeController,
                ),
                _buildThemeOption(
                  title: 'System Default',
                  subtitle: 'Match device settings',
                  icon: Icons.settings_suggest_outlined,
                  value: ThemePreference.system,
                  themeController: themeController,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemePreference value,
    required ThemeController themeController,
    bool isLast = false,
  }) {
    return Obx(() {
      final isSelected = themeController.themePreference == value;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => themeController.setThemePreference(value),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: AppColors.dividerColor(context),
                        width: 1,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [AppColors.primaryColor, AppColors.secondaryColor]
                          : [
                              AppColors.primaryColor.withValues(alpha: 0.15),
                              AppColors.secondaryColor.withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? primaryColor
                              : AppColors.secondaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryColor,
                          AppColors.secondaryColor,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: AppColors.white,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderColor(context),
                        width: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: _profileData?['fullName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: _profileData?['phone'] ?? '',
    );
    final cityController = TextEditingController(
      text: _profileData?['city'] ?? '',
    );
    final experienceController = TextEditingController(
      text: _profileData?['experience'] ?? '',
    );
    final bioController = TextEditingController(
      text: _profileData?['bio'] ?? '',
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Profile',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, __) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.95),
                              Colors.white.withValues(alpha: 0.9),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 60,
                              spreadRadius: 10,
                              offset: const Offset(0, 30),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Icon
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.elasticOut,
                                    builder: (_, v, __) => Transform.scale(
                                      scale: v,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              primaryColor,
                                              secondaryColor,
                                              accentColor,
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: primaryColor.withValues(
                                                alpha: 0.5,
                                              ),
                                              blurRadius: 30,
                                              offset: const Offset(0, 15),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                          colors: [primaryColor, accentColor],
                                        ).createShader(bounds),
                                    child: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Update your personal information',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  _buildLuxuryTextField(
                                    controller: nameController,
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    icon: Icons.person_rounded,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLuxuryTextField(
                                    controller: phoneController,
                                    label: 'Phone Number',
                                    hint: 'Enter your phone number',
                                    icon: Icons.phone_rounded,
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLuxuryTextField(
                                    controller: cityController,
                                    label: 'City',
                                    hint: 'Enter your city',
                                    icon: Icons.location_city_rounded,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLuxuryTextField(
                                    controller: experienceController,
                                    label: 'Experience (years)',
                                    hint: 'e.g. 5',
                                    icon: Icons.work_outline_rounded,
                                    keyboardType: TextInputType.number,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildLuxuryTextField(
                                    controller: bioController,
                                    label: 'Bio',
                                    hint: 'Tell clients about yourself',
                                    icon: Icons.info_outline_rounded,
                                    maxLines: 3,
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    children: [
                                      // Cancel
                                      Expanded(
                                        child: SizedBox(
                                          height: 56,
                                          child: OutlinedButton.icon(
                                            onPressed: () => Get.back(),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 22,
                                            ),
                                            label: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.grey[700],
                                              side: BorderSide(
                                                color: Colors.grey[300]!,
                                                width: 2,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Save
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                primaryColor,
                                                secondaryColor,
                                                accentColor,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withValues(
                                                  alpha: 0.5,
                                                ),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: () async {
                                                if (nameController.text
                                                    .trim()
                                                    .isEmpty) {
                                                  Get.snackbar(
                                                    'Required',
                                                    'Please enter your name',
                                                    backgroundColor:
                                                        Colors.orange,
                                                    colorText: Colors.white,
                                                    borderRadius: 16,
                                                    margin:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                  );
                                                  return;
                                                }

                                                showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) => Center(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            32,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                      ),
                                                      child: const Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          CircularProgressIndicator(
                                                            valueColor:
                                                                AlwaysStoppedAnimation(
                                                                  primaryColor,
                                                                ),
                                                          ),
                                                          SizedBox(height: 24),
                                                          Text(
                                                            'Updating profile...',
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );

                                                try {
                                                  await _updateProfileInfo({
                                                    'fullName': nameController
                                                        .text
                                                        .trim(),
                                                    'phone': phoneController
                                                        .text
                                                        .trim(),
                                                    'city': cityController.text
                                                        .trim(),
                                                    'experience':
                                                        experienceController
                                                            .text
                                                            .trim(),
                                                    'bio': bioController.text
                                                        .trim(),
                                                  });
                                                  Navigator.of(
                                                    context,
                                                  ).pop(); // close loading
                                                  Navigator.of(
                                                    context,
                                                  ).pop(); // close edit dialog
                                                } catch (e) {
                                                  Navigator.of(context).pop();
                                                  Get.snackbar(
                                                    'Error',
                                                    'Failed to update profile',
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    borderRadius: 16,
                                                    margin:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                  );
                                                }
                                              },
                                              child: const Center(
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.check_rounded,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Save Changes',
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 0.8,
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
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.blue[50]!,
                                          Colors.indigo[50]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.info_outline_rounded,
                                            color: Colors.blue[700],
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Changes will be saved to your account',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue[900],
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              letterSpacing: 0.3,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              prefixIcon: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withValues(alpha: 0.15),
                      secondaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryColor, size: 22),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryColor, width: 2.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final currentPwController = TextEditingController();
    final newPwController = TextEditingController();
    final confirmPwController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            const Text(
              'Change Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPasswordField(
                controller: currentPwController,
                label: 'Current Password',
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: newPwController,
                label: 'New Password',
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                controller: confirmPwController,
                label: 'Confirm New Password',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryColor, secondaryColor],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () async {
                if (newPwController.text != confirmPwController.text) {
                  Get.snackbar(
                    'Error',
                    'Passwords do not match',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    borderRadius: 16,
                    margin: const EdgeInsets.all(16),
                  );
                  return;
                }
                if (newPwController.text.length < 6) {
                  Get.snackbar(
                    'Error',
                    'Password must be at least 6 characters',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    borderRadius: 16,
                    margin: const EdgeInsets.all(16),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Center(
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(primaryColor),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'Changing password...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
                try {
                  final result = await _authService.changePassword(
                    currentPwController.text,
                    newPwController.text,
                  );
                  Navigator.of(context).pop(); // close loading
                  if (result['success'] == true) {
                    Navigator.of(context).pop(); // close dialog
                    Get.snackbar(
                      'Success',
                      result['message'] ?? 'Password changed successfully',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      borderRadius: 16,
                      margin: const EdgeInsets.all(16),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                    );
                  } else {
                    Get.snackbar(
                      'Error',
                      result['message'] ?? 'Failed to change password',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                      borderRadius: 16,
                      margin: const EdgeInsets.all(16),
                    );
                  }
                } catch (e) {
                  Navigator.of(context).pop();
                  Get.snackbar(
                    'Error',
                    e.toString(),
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    borderRadius: 16,
                    margin: const EdgeInsets.all(16),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Change Password'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'This action cannot be undone. All your data will be permanently deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.snackbar(
                'Info',
                'Account deletion coming soon',
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                borderRadius: 16,
                margin: const EdgeInsets.all(16),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Logout',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, _, __) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(
              opacity: animation,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 60,
                              spreadRadius: 10,
                              offset: const Offset(0, 30),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.elasticOut,
                                  builder: (_, v, __) => Transform.scale(
                                    scale: v,
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFFFF6B6B),
                                            Color(0xFFEE5A6F),
                                            Color(0xFFC06C84),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withValues(
                                              alpha: 0.5,
                                            ),
                                            blurRadius: 30,
                                            offset: const Offset(0, 15),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.power_settings_new_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                ShaderMask(
                                  shaderCallback: (bounds) =>
                                      const LinearGradient(
                                        colors: [
                                          Color(0xFFFF6B6B),
                                          Color(0xFFC06C84),
                                        ],
                                      ).createShader(bounds),
                                  child: const Text(
                                    'Logout Account',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'You\'re about to end this session',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Are you sure you want to logout?',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    // Stay
                                    Expanded(
                                      child: SizedBox(
                                        height: 56,
                                        child: OutlinedButton.icon(
                                          onPressed: () => Get.back(),
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 22,
                                          ),
                                          label: const Text(
                                            'Stay',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryColor,
                                            side: BorderSide(
                                              color: primaryColor.withValues(
                                                alpha: 0.3,
                                              ),
                                              width: 2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Logout
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFFFF6B6B),
                                              Color(0xFFEE5A6F),
                                              Color(0xFFC06C84),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(
                                                0xFFFF6B6B,
                                              ).withValues(alpha: 0.5),
                                              blurRadius: 20,
                                              offset: const Offset(0, 10),
                                            ),
                                          ],
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: () async {
                                              try {
                                                Get.back();
                                                Get.dialog(
                                                  WillPopScope(
                                                    onWillPop: () async =>
                                                        false,
                                                    child: Center(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              32,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                24,
                                                              ),
                                                        ),
                                                        child: const Column(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            CircularProgressIndicator(
                                                              valueColor:
                                                                  AlwaysStoppedAnimation(
                                                                    primaryColor,
                                                                  ),
                                                              strokeWidth: 3,
                                                            ),
                                                            SizedBox(
                                                              height: 24,
                                                            ),
                                                            Text(
                                                              'Logging out...',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  barrierDismissible: false,
                                                );
                                                await _authService.signOut();
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }
                                                AppRoutes.toWelcome();
                                                Get.snackbar(
                                                  'Success',
                                                  'Logged out successfully',
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
                                                  backgroundColor: Colors.green,
                                                  colorText: Colors.white,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                  margin: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  borderRadius: 16,
                                                  icon: const Icon(
                                                    Icons.check_circle_rounded,
                                                    color: Colors.white,
                                                  ),
                                                );
                                              } catch (e) {
                                                if (Get.isDialogOpen ?? false) {
                                                  Get.back();
                                                }
                                                Get.snackbar(
                                                  'Error',
                                                  'Logout failed: $e',
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  borderRadius: 16,
                                                  margin: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                );
                                              }
                                            },
                                            child: const Center(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.logout_rounded,
                                                    color: Colors.white,
                                                    size: 22,
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Logout Now',
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 0.8,
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
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.blue[50]!,
                                        Colors.indigo[50]!,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[100],
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.blue[700],
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Your data is safe & secure',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[900],
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHelpSupport() => Get.snackbar(
    'Info',
    'Help & support coming soon',
    borderRadius: 16,
    margin: const EdgeInsets.all(16),
  );

  void _showTerms() => Get.snackbar(
    'Info',
    'Terms & conditions coming soon',
    borderRadius: 16,
    margin: const EdgeInsets.all(16),
  );

  void _showPrivacyPolicy() => Get.snackbar(
    'Info',
    'Privacy policy coming soon',
    borderRadius: 16,
    margin: const EdgeInsets.all(16),
  );
}

// ─────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────

class _CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.8, size.height * 0.3),
        50.0 * (i + 1),
        paint,
      );
    }
    for (int i = 0; i < 4; i++) {
      canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.7),
        40.0 * (i + 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

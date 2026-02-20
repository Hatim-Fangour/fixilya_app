import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/data/controllers/theme_controller.dart';
import 'package:fixilya_app/services/language_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

class ClientSettingsPage extends StatefulWidget {
  const ClientSettingsPage({super.key});

  @override
  State<ClientSettingsPage> createState() => _ClientSettingsPageState();
}

class _ClientSettingsPageState extends State<ClientSettingsPage> {
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);

  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _smsNotifications = true;

  bool _isLoading = true;
  final bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      // Fetch user settings from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data();
        setState(() {
          _pushNotifications = data?['pushNotifications'] ?? true;
          _emailNotifications = data?['emailNotifications'] ?? false;
          _smsNotifications = data?['smsNotifications'] ?? true;
          _isLoading = false;
        });

        print('✅ Settings loaded successfully');
      } else {
        // Create default settings if document doesn't exist
        await _saveSettingsToFirebase();
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettingsToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .update({
            'pushNotifications': _pushNotifications,
            'emailNotifications': _emailNotifications,
            'smsNotifications': _smsNotifications,
            'settingsUpdatedAt': FieldValue.serverTimestamp(),
          });

      print('✅ Settings saved to Firebase');
    } catch (e) {
      print('❌ Error saving settings: $e');

      // Show error to user
      Get.snackbar(
        'Error',
        'Failed to save settings. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                  spreadRadius: 5,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Header
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                primaryColor.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.lock_reset,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Change Password',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Update your account password',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Current Password Field
                    _buildPremiumTextField(
                      controller: currentPasswordController,
                      label: 'Current Password',
                      hint: 'Enter your current password',
                      icon: Icons.lock_outline,
                      obscureText: !showCurrentPassword,
                      onToggleVisibility: () {
                        setState(
                          () => showCurrentPassword = !showCurrentPassword,
                        );
                      },
                    ),

                    SizedBox(height: 20),

                    // New Password Field
                    _buildPremiumTextField(
                      controller: newPasswordController,
                      label: 'New Password',
                      hint: 'Enter your new password',
                      icon: Icons.vpn_key_outlined,
                      obscureText: !showNewPassword,
                      onToggleVisibility: () {
                        setState(() => showNewPassword = !showNewPassword);
                      },
                    ),

                    SizedBox(height: 12),

                    // Password Requirements
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[100]!, width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: Colors.blue[700],
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Minimum 6 characters required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // Confirm Password Field
                    _buildPremiumTextField(
                      controller: confirmPasswordController,
                      label: 'Confirm New Password',
                      hint: 'Re-enter your new password',
                      icon: Icons.check_circle_outline,
                      obscureText: !showConfirmPassword,
                      onToggleVisibility: () {
                        setState(
                          () => showConfirmPassword = !showConfirmPassword,
                        );
                      },
                    ),

                    SizedBox(height: 32),

                    // Premium Action Buttons
                    Row(
                      children: [
                        // Cancel Button
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  currentPasswordController.dispose();
                                  newPasswordController.dispose();
                                  confirmPasswordController.dispose();
                                  Get.back();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(width: 12),

                        // Update Button
                        Expanded(
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.8),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  // Validation
                                  if (currentPasswordController.text.isEmpty ||
                                      newPasswordController.text.isEmpty ||
                                      confirmPasswordController.text.isEmpty) {
                                    Get.snackbar(
                                      'Missing Information',
                                      'Please fill in all fields',
                                      backgroundColor: Colors.orange,
                                      colorText: Colors.white,
                                      icon: Icon(
                                        Icons.warning,
                                        color: Colors.white,
                                      ),
                                      snackPosition: SnackPosition.BOTTOM,
                                      margin: EdgeInsets.all(16),
                                      borderRadius: 12,
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text !=
                                      confirmPasswordController.text) {
                                    Get.snackbar(
                                      'Password Mismatch',
                                      'New passwords do not match',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                      icon: Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      snackPosition: SnackPosition.BOTTOM,
                                      margin: EdgeInsets.all(16),
                                      borderRadius: 12,
                                    );
                                    return;
                                  }

                                  if (newPasswordController.text.length < 6) {
                                    Get.snackbar(
                                      'Weak Password',
                                      'Password must be at least 6 characters',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                      icon: Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      snackPosition: SnackPosition.BOTTOM,
                                      margin: EdgeInsets.all(16),
                                      borderRadius: 12,
                                    );
                                    return;
                                  }

                                  Get.back();
                                  await _changePassword(
                                    currentPasswordController.text,
                                    newPasswordController.text,
                                  );

                                  currentPasswordController.dispose();
                                  newPasswordController.dispose();
                                  confirmPasswordController.dispose();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Update',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ NEW: Language Section
  Widget _buildLanguageSection() {
    final languageService = Get.find<LanguageService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Language'),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildLanguageOption(
                title: 'English',
                nativeName: 'English',
                icon: '🇬🇧',
                languageCode: 'en',
                languageService: languageService,
              ),
              Divider(height: 1, color: AppColors.dividerColor(context)),
              _buildLanguageOption(
                title: 'Arabic',
                nativeName: 'العربية',
                icon: '🇲🇦',
                languageCode: 'ar',
                languageService: languageService,
              ),
              Divider(height: 1, color: AppColors.dividerColor(context)),
              _buildLanguageOption(
                title: 'French',
                nativeName: 'Français',
                icon: '🇫🇷',
                languageCode: 'fr',
                languageService: languageService,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Language Option Tile
  Widget _buildLanguageOption({
    required String title,
    required String nativeName,
    required String icon,
    required String languageCode,
    required LanguageService languageService,
    bool isLast = false,
  }) {
    return Obx(() {
      final isSelected = languageService.locale.languageCode == languageCode;

      return ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryColor
                : AppColors.glassWhiteColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryColor
                  : AppColors.borderColor(context),
              width: 1,
            ),
          ),
          child: Center(child: Text(icon, style: TextStyle(fontSize: 24))),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.textPrimaryColor(context)
                : AppColors.textSecondaryColor(context),
          ),
        ),
        subtitle: Text(
          nativeName,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: primaryColor, size: 24)
            : Container(
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
        onTap: () async {
          await languageService.changeLanguage(languageCode);

          Get.snackbar(
            'Language Updated',
            'Switched to $title',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: EdgeInsets.all(16),
            borderRadius: 12,
            duration: Duration(seconds: 2),
            icon: Icon(Icons.check_circle, color: Colors.white),
          );
        },
      );
    });
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Container(
                margin: EdgeInsets.all(10),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.1),
                      primaryColor.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: primaryColor),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: Colors.grey[600],
                ),
                onPressed: onToggleVisibility,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Update password
      await user.updatePassword(newPassword);

      Get.snackbar(
        '✅ Success',
        'Password changed successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to change password';

      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }

      Get.snackbar(
        'Error',
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey[50]!],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.2),
                blurRadius: 30,
                offset: Offset(0, 10),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Premium Warning Icon
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.red[400]!, Colors.red[600]!],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),

                SizedBox(height: 24),

                // Title
                Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),

                SizedBox(height: 12),

                // Subtitle
                Text(
                  'Are you absolutely sure?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),

                SizedBox(height: 24),

                // Description
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                  ),
                  child: Text(
                    'This action cannot be undone. All your data will be permanently erased from our servers.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Premium warning box with gradient border
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red[300]!, Colors.red[500]!],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.2),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(2), // Gradient border width
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.red[700],
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'This will permanently delete:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[900],
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        ...[
                          'Your complete profile & personal data',
                          'All bookings & transaction history',
                          'Invoice records & payment details',
                          'Reviews & ratings you\'ve given',
                        ].map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: Colors.red[400],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.red[900],
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
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

                SizedBox(height: 32),

                // Premium Buttons
                Row(
                  children: [
                    // Cancel Button
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: 12),

                    // Delete Button
                    Expanded(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[500]!, Colors.red[700]!],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _confirmDeleteAccount();
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_forever,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your password to confirm:'),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount(passwordController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Confirm Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(String password) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading
      Get.dialog(
        Center(
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 16),
                Text('Deleting account...'),
              ],
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .delete();

      // Delete related data (bookings, reviews, etc.)
      final batch = FirebaseFirestore.instance.batch();

      // Delete bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('clientId', isEqualTo: user.uid)
          .get();

      for (var doc in bookingsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('clientId', isEqualTo: user.uid)
          .get();

      for (var doc in reviewsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      // Delete Firebase Auth account
      await user.delete();

      // Close loading
      Get.back();

      // Show success and navigate to login
      Get.snackbar(
        '✅ Account Deleted',
        'Your account has been permanently deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );

      // Navigate to login (adjust route as needed)
      // Get.offAllNamed('/login');
    } on FirebaseAuthException catch (e) {
      Get.back(); // Close loading

      String message = 'Failed to delete account';
      if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      }

      Get.snackbar(
        'Error',
        message,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor(context),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.white,
          ),
        ),
        iconTheme: IconThemeData(color: AppColors.white),
        backgroundColor: AppColors.pagesAppBar(context),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),

                  // ✅ THEME SECTION (NEW)
                  _buildThemeSection(),

                  // SizedBox(height: 20),

                  // _buildLanguageSection(),
                  SizedBox(height: 20),

                  _buildSection('Notifications'),
                  _buildSwitchTile(
                    'Push Notifications',
                    'Receive push notifications',
                    _pushNotifications,
                    (value) async {
                      setState(() => _pushNotifications = value);
                      await _saveSettingsToFirebase();
                    },
                  ),
                  _buildSwitchTile(
                    'Email Notifications',
                    'Receive email updates',
                    _emailNotifications,
                    (value) async {
                      setState(() => _emailNotifications = value);
                      await _saveSettingsToFirebase();
                    },
                  ),
                  _buildSwitchTile(
                    'SMS Notifications',
                    'Receive SMS alerts',
                    _smsNotifications,
                    (value) async {
                      setState(() => _smsNotifications = value);
                      await _saveSettingsToFirebase();
                    },
                  ),
                  SizedBox(height: 20),
                  _buildSection('Account'),
                  _buildListTile(
                    'Change Password',
                    Icons.lock_outline,
                    _showChangePasswordDialog,
                  ),
                  _buildListTile(
                    'Privacy Settings',
                    Icons.privacy_tip_outlined,
                    () {},
                  ),
                  _buildListTile(
                    'Delete Account',
                    Icons.delete_outline,
                    _showDeleteAccountDialog,
                    isDestructive: true,
                  ),
                  SizedBox(height: 20),
                  _buildSection('About'),
                  _buildListTile(
                    'Terms & Conditions',
                    Icons.description_outlined,
                    () {},
                  ),
                  _buildListTile(
                    'Privacy Policy',
                    Icons.policy_outlined,
                    () {},
                  ),
                  _buildListTile('Help & Support', Icons.help_outline, () {}),
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ✅ NEW: Theme Section
  Widget _buildThemeSection() {
    final themeController = Get.find<ThemeController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Appearance'),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(12),
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
              Divider(height: 1, color: AppColors.dividerColor(context)),
              _buildThemeOption(
                title: 'Dark Mode',
                subtitle: 'Easy on the eyes',
                icon: Icons.dark_mode_outlined,
                value: ThemePreference.dark,
                themeController: themeController,
              ),
              Divider(height: 1, color: AppColors.dividerColor(context)),
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
    );
  }

  // ✅ NEW: Theme Option Tile
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

      return ListTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryColor
                : AppColors.glassWhiteColor(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.borderColor(context)
                  : AppColors.borderColor(context),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isSelected ? AppColors.white : AppColors.secondaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? AppColors.textPrimaryColor(context)
                : AppColors.textSecondaryColor(context),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: primaryColor, size: 24)
            : Container(
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
        onTap: () async {
          await themeController.setThemePreference(value);

          Get.snackbar(
            'Theme Updated',
            'Switched to ${title.toLowerCase()}',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            margin: EdgeInsets.all(16),
            borderRadius: 12,
            duration: Duration(seconds: 2),
            icon: Icon(Icons.check_circle, color: Colors.white),
          );
        },
      );
    });
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 13)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: primaryColor,
      ),
    );
  }

  Widget _buildListTile(
    String title,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : primaryColor),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDestructive
                ? Colors.red
                : AppColors.textPrimaryColor(context),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: AppColors.textSecondaryColor(context),
        ),
        onTap: onTap,
      ),
    );
  }
}

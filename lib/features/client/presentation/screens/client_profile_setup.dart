import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/services/app_config_service.dart';
import 'package:fixilya_app/shared/widgets/dropdown_list.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';
import 'package:flutter/material.dart';
import 'package:fixilya_app/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';

class ClientProfileSetup extends StatefulWidget {
  const ClientProfileSetup({super.key});

  @override
  State<ClientProfileSetup> createState() => _ClientProfileSetupState();
}

class _ClientProfileSetupState extends State<ClientProfileSetup>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _storageService = StorageService();

  // Premium Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  late final CloudinaryService _cloudinaryService;
  late final FirebaseImageService _firebaseImageService;

  // Controllers
  final _cityController = GenericDropdownController<String>();
  final _addressController = TextEditingController();

  // State
  File? _profileImage;
  bool _isLoading = false;

  // Dynamic data from Firestore (falls back to GlobalVariables)
  List<String> _cities = GlobalVariables.cities.skip(1).toList();

  // Animation
  // Animation Controllers
  late AnimationController _fadeController;

  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // ✅ Get services from GetX
    try {
      _cloudinaryService = Get.find<CloudinaryService>();
      _firebaseImageService = Get.find<FirebaseImageService>();

      if (kDebugMode) debugPrint('Cloud Name: ${_cloudinaryService.cloudName}');
      if (kDebugMode) debugPrint('✅ Services loaded successfully');
      if (kDebugMode)
        debugPrint('🔍 Cloudinary Cloud Name: ${_cloudinaryService.cloudName}');
      if (kDebugMode)
        debugPrint(
          '🔍 Cloudinary Upload Preset: ${_cloudinaryService.uploadPreset}',
        );
    } catch (e) {
      if (kDebugMode) debugPrint('❌ ERROR: Services not found!');
      if (kDebugMode) debugPrint('Error: $e');
    }
    // Load cities from Firestore (non-blocking)
    AppConfigService().getCities().then((cities) {
      if (mounted && cities.isNotEmpty) {
        setState(() => _cities = cities);
      }
    });

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(begin: Offset(0, 0.1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final image = await _cloudinaryService.pickImage();
    if (image != null) {
      setState(() => _profileImage = image);
    }
  }

  Future<void> _saveProfile() async {
    if (kDebugMode) debugPrint('🚀 Starting profile save...');
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('❌ No user found');
        throw Exception('User not found');
      }

      if (kDebugMode) debugPrint('✅ User found: ${user.uid}');
      if (kDebugMode) debugPrint('📋 Profile data:');
      // if (kDebugMode) debugPrint('   City: ${_cityController.text.trim()}');
      if (kDebugMode)
        debugPrint('   Address: ${_addressController.text.trim()}');

      // Show upload progress dialog
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 32),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Setting up your profile...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This may take a moment',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // ✅ Upload profile picture to Cloudinary
      String? profileImageUrl;

      if (kDebugMode)
        debugPrint(
          _profileImage == null
              ? 'ℹ️ No profile image selected'
              : '📸 Profile image selected: ${_profileImage!.path}',
        );
      if (_profileImage != null) {
        if (kDebugMode) debugPrint('📤 Uploading profile image...');

        try {
          profileImageUrl = await _cloudinaryService
              .uploadImage(
                imageFile: _profileImage!,
                folder: 'profiles',
                publicId: 'profile_${user.uid}',
                timeoutSeconds: 30, // ✅ Shorter
              )
              .timeout(
                Duration(seconds: 35), // ✅ Extra safety
                onTimeout: () {
                  if (kDebugMode) debugPrint('⏱️ Timed out');
                  return null;
                },
              );

          if (profileImageUrl != null) {
            if (kDebugMode)
              debugPrint('✅ Profile picture uploaded: $profileImageUrl');

            // Save URL to Firebase
            await _firebaseImageService.saveProfileImageUrl(
              userId: user.uid,
              imageUrl: profileImageUrl,
              userType: 'clients',
            );
            if (kDebugMode)
              debugPrint('✅ Profile picture URL saved to Firebase');
          } else {
            if (kDebugMode)
              debugPrint('⚠️ Profile picture upload returned null');
          }
        } catch (e) {
          if (kDebugMode) debugPrint('❌ Profile picture upload failed: $e');
        }
      } else {
        if (kDebugMode) debugPrint('ℹ️ No profile picture to upload');
      }

      // Save profile data to Firestore
      if (kDebugMode) debugPrint('💾 Saving profile to Firestore...');

      final profileData = {
        'city': _cityController.value ?? '',
        'address': _addressController.text.trim(),
        'profilePicture': profileImageUrl ?? '',
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (kDebugMode) debugPrint('📝 Profile data to save: $profileData');

      await FirebaseFirestore.instance
          .collection('clients')
          .doc(user.uid)
          .set(profileData, SetOptions(merge: true));

      if (kDebugMode) debugPrint('✅ Client collection updated');

      // Also update users collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) debugPrint('✅ Users collection updated');

      setState(() => _isLoading = false);

      // Close loading dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      // Show success message
      Get.snackbar(
        'Success!',
        'Your profile has been created successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        icon: Icon(Icons.check_circle, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 3),
      );

      if (kDebugMode) debugPrint('✅ Profile setup complete!');

      // Navigate to home
      await Future.delayed(Duration(milliseconds: 500));
      AppRoutes.toHome();
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);

      // Close loading dialog if open
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      if (kDebugMode) debugPrint('❌ ERROR saving profile: $e');
      if (kDebugMode) debugPrint('Stack trace: $stackTrace');

      Get.snackbar(
        'Error',
        'Failed to save profile: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, secondaryColor, accentColor],
              ),
            ),
          ),

          // Decorative Circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.1), Colors.transparent],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          // Content - Single Screen View (No Scroll)
          SafeArea(
            child: _isLoading
                ? _buildLoadingState()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Back Button
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_back,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Get.back(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Main Content
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Header
                                _buildCompactHeader(),

                                // Profile Picture
                                _buildCompactProfilePicture(),

                                // Form Card
                                _buildCompactFormCard(),

                                // Buttons
                                Column(
                                  children: [
                                    _buildCompleteButton(),
                                    SizedBox(height: 12),
                                    _buildSkipButton(),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 3,
          ),
          SizedBox(height: 20),
          Text(
            'Creating your profile...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Column(
      children: [
        // Icon
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.person_add_rounded, size: 40, color: Colors.white),
        ),

        SizedBox(height: 16),

        // Title
        Text(
          'Complete Your Profile',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),

        SizedBox(height: 8),

        Text(
          'Just a few more details',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactProfilePicture() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Profile Container
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 25,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: _profileImage != null
                ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover))
                : Icon(Icons.person_rounded, size: 60, color: primaryColor),
          ),

          // Camera Button
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.5),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFormCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // City Field
                // _buildCompactTextField(
                //   controller: _cityController,
                //   label: 'City',
                //   hint: 'Your city',
                //   icon: Icons.location_city_rounded,
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Required';
                //     }
                //     return null;
                //   },
                // ),
                GenericDropdown<String>(
                  controller: _cityController,
                  items: _cities,
                  label: 'City',
                  hint: 'Select your city',
                  itemLabel: (city) => city,
                  onChanged: (value) {
                    if (kDebugMode) debugPrint('Selected: $value');
                  },
                  validator: (value) =>
                      value == null ? 'Please select a city' : null,
                ),

                SizedBox(height: 16),

                // Address Field
                _buildCompactTextField(
                  controller: _addressController,
                  label: 'Address',
                  hint: 'Your full address',
                  icon: Icons.home_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
            prefixIcon: Container(
              margin: EdgeInsets.all(10),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            errorStyle: TextStyle(
              color: Colors.red.shade100,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCompleteButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.white.withOpacity(0.95)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _saveProfile,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: primaryColor, size: 22),
                SizedBox(width: 10),
                Text(
                  'Complete Profile',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: primaryColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton() {
    return TextButton(
      onPressed: () => AppRoutes.toWidgetTree(),
      style: TextButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        'Skip for now',
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

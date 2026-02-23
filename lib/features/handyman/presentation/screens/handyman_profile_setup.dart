import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/services/admin_notification_service.dart';
import 'package:fixilya_app/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:fixilya_app/shared/widgets/dropdown_list.dart';

class HandymanProfileSetup extends StatefulWidget {
  const HandymanProfileSetup({super.key});

  @override
  State<HandymanProfileSetup> createState() => _HandymanProfileSetupState();
}

class _HandymanProfileSetupState extends State<HandymanProfileSetup>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _cityController = GenericDropdownController<String>();
  final _experienceController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _bioController = TextEditingController();

  // State
  File? _profileImage;
  List<File> _workImages = [];
  final List<Map<String, dynamic>> _selectedSkills = [];
  bool _isLoading = false;
  int _currentStep = 0;
  static const double _maxStepWidth = 500.0;
  static const double _stepHeight = 550.0;

  // ✅ ADD THESE TWO LINES:
  String? _uploadedProfileUrl;
  List<String> _uploadedWorkUrls = [];

  // Animation Controllers
  late AnimationController _fadeController;

  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late final CloudinaryService _cloudinaryService;
  late final FirebaseImageService _firebaseImageService;
  @override
  void initState() {
    super.initState();
    // ✅ Get services from GetX
    try {
      _cloudinaryService = Get.find<CloudinaryService>();
      _firebaseImageService = Get.find<FirebaseImageService>();

      print('Cloud Name: ${_cloudinaryService.cloudName}');
      print('✅ Services loaded successfully');
      print('🔍 Cloudinary Cloud Name: ${_cloudinaryService.cloudName}');
      print('🔍 Cloudinary Upload Preset: ${_cloudinaryService.uploadPreset}');
    } catch (e) {
      print('❌ ERROR: Services not found!');
      print('Error: $e');
    }
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
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final image = await _cloudinaryService.pickImage();
    if (image != null) {
      setState(() => _profileImage = image);
    }
  }

  Future<void> _pickWorkImages() async {
    final images = await _cloudinaryService.pickMultipleImages(maxImages: 10);
    if (images.isNotEmpty) {
      setState(() {
        _workImages.addAll(images);
        if (_workImages.length > 10) {
          _workImages = _workImages.take(10).toList();
        }
      });
    }
  }

  void _toggleSkill(Map<String, dynamic> skill) {
    setState(() {
      final index = _selectedSkills.indexWhere(
        (s) => s['name'] == skill['name'],
      );
      if (index >= 0) {
        _selectedSkills.removeAt(index);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  // ✅ Save Profile with Cloudinary Native Transformations
  Future<void> _saveProfile() async {
    print('🚀 Starting profile save...');

    // Validation
    if (_currentStep == 1) {
      if (!_formKey.currentState!.validate()) {
        print('❌ Form validation failed');
        return;
      }
    } else if (_currentStep > 1) {
      if (_cityController.isEmpty ||
          _experienceController.text.trim().isEmpty) {
        Get.snackbar(
          'Incomplete Information',
          'Please complete basic information',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.warning,
          colorText: Colors.white,
        );
        return;
      }
    }

    if (_selectedSkills.isEmpty) {
      Get.snackbar(
        'Missing Information',
        'Please select at least one skill',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not found');

      print('✅ User: ${user.uid}');

      // ✅ Variables for image URLs
      String? profilePictureUrl;
      List<String> workImageUrls = [];

      // Show progress dialog
      String currentStep = 'Initializing...';

      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Center(
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
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
                      SizedBox(height: 12),
                      Text(
                        currentStep,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        barrierDismissible: false,
      );

      void updateProgress(String step) {
        currentStep = step;
        print('📍 $step');
        if (Get.isDialogOpen ?? false) {
          Get.back();
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
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
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
                      SizedBox(height: 12),
                      Text(
                        step,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            barrierDismissible: false,
          );
        }
      }

      // ✅ STEP 1: Upload profile picture to Cloudinary FROM FLUTTER
      if (_profileImage != null) {
        updateProgress(
          'Uploading profile picture...\nOptimizing with face detection',
        );

        try {
          profilePictureUrl = await _cloudinaryService.uploadImage(
            imageFile: _profileImage!,
            folder: 'profiles',
            publicId: 'profile_${user.uid}',
            isProfilePicture: true,
            timeoutSeconds: 60,
            maxRetries: 2,
          );

          if (profilePictureUrl != null) {
            print('✅ Profile picture uploaded to Cloudinary');
            print('🔗 URL: $profilePictureUrl');

            if (mounted) {
              setState(() {
                _uploadedProfileUrl = profilePictureUrl;
              });
            }
          } else {
            print('⚠️ Profile picture upload failed');
          }
        } catch (e) {
          print('❌ Profile picture error: $e');
        }
      }

      // ✅ STEP 2: Upload work images to Cloudinary FROM FLUTTER
      if (_workImages.isNotEmpty) {
        updateProgress(
          'Uploading work images (0/${_workImages.length})...\nCloudinary is compressing...',
        );

        try {
          workImageUrls = await _cloudinaryService.uploadMultipleImages(
            imageFiles: _workImages,
            folder: 'work_images',
            timeoutSeconds: 60,
            onProgress: (current, total, status) {
              updateProgress(
                'Uploading work images ($current/$total)...\nCloudinary is optimizing...',
              );
            },
          );

          if (workImageUrls.isNotEmpty) {
            print(
              '✅ ${workImageUrls.length} work images uploaded to Cloudinary',
            );
            print('🔗 URLs: $workImageUrls');

            if (mounted) {
              setState(() {
                _uploadedWorkUrls = workImageUrls;
              });
            }
          } else {
            print('⚠️ No work images uploaded');
          }
        } catch (e) {
          print('❌ Work images error: $e');
        }
      }

      // ✅ STEP 3: Send Cloudinary URLs to backend to save in Firebase
      updateProgress('Saving profile data to server...');
      print('📋 _selectedSkills Data: $_selectedSkills');

      final api = ApiClient();

      final response = await api.userDio.post(
        '/users/complete-profile',
        data: {
          'uid': user.uid,
          'userType': 'handyman',
          'fullName': user.displayName ?? '',
          'phone': user.phoneNumber ?? '',
          'city': _cityController.value ?? '',
          'experience': _experienceController.text.trim(),
          'hourlyRate': double.tryParse(_hourlyRateController.text) ?? 0,
          'bio': _bioController.text.trim(),
          'skills': _selectedSkills.map((s) => s['name']).toList(),
          'profilePicture': profilePictureUrl ?? '', // ✅ Cloudinary URL
          'workImages': workImageUrls, // ✅ Cloudinary URLs
        },
      );

      final responseData = response.data;

      // ✅ Close dialog
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      setState(() => _isLoading = false);

      // ✅ Check response
      if (responseData['success'] == true) {
        print('✅ Backend response successful!');

        final data = responseData['data'];
        final isNewUser = data['isNewUser'] ?? false;

        print('✅ Profile setup complete!');
        print('   Profile Picture: ${profilePictureUrl ?? "None"}');
        print('   Work Images: ${workImageUrls.length} images');
        print(
          '   New User: ${isNewUser ? "Yes - Admin notified" : "No - Update only"}',
        );

        // ✅ Show success
        Get.snackbar(
          'Success!',
          responseData['message'] ?? 'Profile created successfully!',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.success,
          colorText: Colors.white,
          icon: Icon(Icons.check_circle, color: Colors.white),
          margin: EdgeInsets.all(16),
          borderRadius: 12,
          duration: Duration(seconds: 3),
        );

        await Future.delayed(Duration(milliseconds: 500));
        AppRoutes.toHome();
      } else {
        throw Exception(responseData['message'] ?? 'Failed to save profile');
      }
    } on DioException catch (e) {
      setState(() => _isLoading = false);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print('❌ DIO ERROR: ${e.type}');
      print('   Status: ${e.response?.statusCode}');
      print('   Response: ${e.response?.data}');

      String errorMessage = 'Failed to save profile. Please try again.';

      if (e.response?.data != null && e.response!.data is Map) {
        errorMessage = e.response!.data['message'] ?? errorMessage;
      }

      Get.snackbar(
        'Error',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        icon: Icon(Icons.error_outline, color: Colors.white),
        margin: EdgeInsets.all(16),
        borderRadius: 12,
        duration: Duration(seconds: 4),
      );
    } catch (e, stackTrace) {
      setState(() => _isLoading = false);

      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      print('❌ ERROR: $e');
      print('Stack: $stackTrace');

      Get.snackbar(
        'Error',
        'Failed to save profile. Please check your connection and try again.',
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
      backgroundColor: AppColors.backgroundColor(context),
      body: Stack(
        children: [
          // Gradient Background Header
          Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryColor,
                  AppColors.secondaryColor,
                  AppColors.accentColor,
                ],
              ),
            ),
            child: CustomPaint(painter: CirclePatternPainter()),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Premium Header
                _buildPremiumHeader(),

                // Stepper Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primaryColor,
                            ),
                          ),
                        )
                      : _buildStepperContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // Title
              Text(
                'Complete Your Profile',
                style: TextStyle(
                  color: AppColors.textPrimaryColor(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Let clients know about your expertise',
                style: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),

              SizedBox(height: 20),

              // Progress Indicator
              Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${_currentStep + 1} of 4',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${((_currentStep + 1) / 4 * 100).toInt()}%',
                      style: TextStyle(
                        color: AppColors.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 10),

              // Linear Progress
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / 4,
                  minHeight: 3,
                  backgroundColor: AppColors.cardColor(
                    context,
                  ).withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperContent() {
    // ✅ Remove SingleChildScrollView for non-scrollable layout
    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Step Content Card - Expanded to fill available space
          Expanded(
            child: Container(
              padding: EdgeInsets.all(20), // Reduced from 24
              decoration: BoxDecoration(
                color: AppColors.cardColor(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                child: _buildCurrentStep(),
              ),
            ),
          ),

          SizedBox(height: 20), // Reduced from 24
          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildProfilePictureStep();
      case 1:
        return _buildBasicInfoStep();
      case 2:
        return _buildSkillsStep();
      case 3:
        return _buildPreviousWorkStep();
      default:
        return Container();
    }
  }

  Widget _buildProfilePictureStep() {
    final bool canRemove = _profileImage != null || _uploadedProfileUrl != null;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _maxStepWidth,
          // minHeight: _stepHeight, // ✅ Add min height
          // maxHeight: _stepHeight, // ✅ Add max height
        ),
        child: Column(
          key: ValueKey('profile_picture'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step Icon
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.person, color: Colors.white, size: 60),
            ),

            SizedBox(height: 20),

            Text(
              'Profile Picture',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Add a professional photo (Optional)',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: 32),

            // Profile Image Picker
            GestureDetector(
              onTap: _pickProfileImage,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImage == null
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryColor.withValues(alpha: 0.1),
                            AppColors.secondaryColor.withValues(alpha: 0.05),
                          ],
                        )
                      : null,
                  border: Border.all(color: AppColors.primaryColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: _uploadedProfileUrl != null
                    ? ClipOval(
                        child: Image.network(
                          _uploadedProfileUrl!,
                          fit: BoxFit.cover,
                          width: 180,
                          height: 180,
                        ),
                      )
                    : _profileImage != null
                    ? ClipOval(
                        // ✅ Show local file as preview
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: 180,
                          height: 180,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            size: 50,
                            color: AppColors.primaryColor,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Add Photo',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ✅ FIXED - Only one "Remove Photo" button
            SizedBox(height: 20),

            TextButton.icon(
              onPressed: canRemove
                  ? () => setState(() => _profileImage = null)
                  : null,
              icon: Icon(
                Icons.delete_outline,
                color: canRemove
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.5),
              ),
              label: Text(
                'Remove Photo',
                style: TextStyle(
                  color: canRemove
                      ? Colors.red
                      : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxStepWidth),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            // Only this step gets minimal scrolling if keyboard appears
            child: Column(
              key: ValueKey('basic_info'),
              mainAxisSize: MainAxisSize.min,
              children: [
                // Step Icon - Smaller
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryColor,
                        AppColors.secondaryColor,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                ),

                SizedBox(height: 20),

                Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),

                SizedBox(height: 34),

                GenericDropdown<String>(
                  controller: _cityController,
                  items: GlobalVariables.cities.skip(1).toList(),
                  label: 'City',
                  hint: 'Select your city',
                  itemLabel: (city) => city,
                  onChanged: (value) => print('Selected: $value'),
                  validator: (value) =>
                      value == null ? 'Please select a city' : null,
                ),

                SizedBox(height: 15),

                _buildUltraCompactTextField(
                  controller: _experienceController,
                  label: 'Experience (years)',
                  icon: Icons.work,
                  hint: 'Years',
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Required' : null,
                ),

                SizedBox(height: 15),

                _buildUltraCompactTextField(
                  controller: _hourlyRateController,
                  label: 'Hourly Rate (DH)',
                  icon: Icons.attach_money,
                  hint: '150',
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (double.tryParse(value!) == null) return 'Invalid';
                    return null;
                  },
                ),

                SizedBox(height: 15),

                _buildUltraCompactTextField(
                  controller: _bioController,
                  label: 'Bio',
                  icon: Icons.description,
                  hint: 'Tell clients about your expertise...',
                  maxLines: 2,
                  validator: (value) {
                    if (value?.isEmpty ?? true) return 'Required';
                    if (value!.length < 20) return 'Min 20 chars';
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

  Widget _buildSkillsStep() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _maxStepWidth),
        child: Column(
          key: ValueKey('skills'),
          mainAxisSize: MainAxisSize.min,
          children: [
            // Step Icon - Smaller
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.build, color: Colors.white, size: 60),
            ),

            SizedBox(height: 20),

            Text(
              'Your Skills',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Select at least one skill',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
            ),

            SizedBox(height: 10),

            // Selected Count Badge - Compact
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.secondaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: AppColors.primaryColor,
                    size: 16,
                  ),
                  SizedBox(width: 6),
                  Text(
                    '${_selectedSkills.length} skill${_selectedSkills.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),

            // ✅ Skills Grid - Scrollable to prevent overflow
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: GlobalVariables.availableSkills
                      .skip(1)
                      .toList()
                      .map((skill) {
                        final isSelected = _selectedSkills.any(
                          (s) => s['name'] == skill['name'],
                        );
                        return _buildCompactSkillChip(skill, isSelected);
                      })
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousWorkStep() {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _maxStepWidth,
          minHeight: _stepHeight, // ✅ Add consistent height
          maxHeight: _stepHeight, // ✅ Add consistent height
        ),
        child: Column(
          key: ValueKey('previous_work'),
          children: [
            // Header content (non-scrollable)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(Icons.photo_library, color: Colors.white, size: 32),
            ),

            SizedBox(height: 20),

            Text(
              'Previous Work',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimaryColor(context),
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Showcase your best work (Optional)',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryColor(context),
              ),
            ),

            SizedBox(height: 16),

            // ✅ Make images grid scrollable
            Expanded(
              child: _workImages.isEmpty
                  ? _buildEmptyWorkState()
                  : SingleChildScrollView(child: _buildWorkImagesGrid()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWorkState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _pickWorkImages,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.secondaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 60,
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Add Work Photos',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  Widget _buildWorkImagesGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // ✅ Grid of images
          GridView.builder(
            shrinkWrap: true, // ✅ Important for SingleChildScrollView
            physics:
                NeverScrollableScrollPhysics(), // ✅ Let parent handle scrolling
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: _workImages.length,
            itemBuilder: (context, index) {
              return _buildWorkImageCard(_workImages[index], index);
            },
          ),

          SizedBox(height: 16),

          // ✅ Add more images button
          GestureDetector(
            onTap: _pickWorkImages,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.secondaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate,
                    color: AppColors.primaryColor,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Add More Images',
                    style: TextStyle(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

  Widget _buildWorkImageCard(File image, int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ✅ Image
            Image.file(image, fit: BoxFit.cover),

            // ✅ Delete button - Top Right Corner INSIDE the image
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _workImages.removeAt(index);
                  });
                },
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact text field builder
  Widget _buildUltraCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textPrimaryColor(context),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: AppColors.textSecondaryColor(context),
          fontWeight: FontWeight.w500,
        ),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 11,
          color: AppColors.textSecondaryColor(context),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        prefixIcon: Container(
          margin: EdgeInsets.all(6),
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryColor.withValues(alpha: 0.15),
                AppColors.secondaryColor.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AppColors.primaryColor, size: 16),
        ),
        filled: true,
        fillColor: AppColors.cardColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.borderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        errorStyle: TextStyle(fontSize: 10),
      ),
      validator: validator,
    );
  }

  Widget _buildCompactSkillChip(Map<String, dynamic> skill, bool isSelected) {
    return GestureDetector(
      onTap: () => _toggleSkill(skill),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                )
              : null,
          color: isSelected ? null : AppColors.cardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
            width: isSelected ? 1 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              skill['icon'],
              size: 16,
              color: isSelected ? Colors.white : AppColors.primaryColor,
            ),
            SizedBox(width: 8),
            Text(
              skill['name'],
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.textPrimaryColor(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 6),
              Icon(Icons.check_circle, color: Colors.white, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  // Widget _buildPremiumSkillChip(Map<String, dynamic> skill, bool isSelected) {
  //   return GestureDetector(
  //     onTap: () => _toggleSkill(skill),
  //     child: AnimatedContainer(
  //       duration: Duration(milliseconds: 200),
  //       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  //       decoration: BoxDecoration(
  //         gradient: isSelected
  //             ? LinearGradient(
  //                 colors: [AppColors.primaryColor, AppColors.secondaryColor],
  //               )
  //             : null,
  //         color: isSelected ? null : AppColors.cardColor(context),
  //         borderRadius: BorderRadius.circular(16),
  //         border: Border.all(
  //           color: isSelected ? AppColors.primaryColor : Colors.grey.shade300,
  //           width: isSelected ? 2 : 1,
  //         ),
  //         boxShadow: isSelected
  //             ? [
  //                 BoxShadow(
  //                   color: AppColors.primaryColor.withValues(alpha: 0.3),
  //                   blurRadius: 10,
  //                   offset: Offset(0, 4),
  //                 ),
  //               ]
  //             : [
  //                 BoxShadow(
  //                   color: Colors.black.withValues(alpha: 0.03),
  //                   blurRadius: 5,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //       ),
  //       child: Row(
  //         mainAxisSize: MainAxisSize.min,
  //         children: [
  //           FaIcon(
  //             skill['icon'],
  //             size: 20,
  //             color: isSelected ? Colors.white : AppColors.primaryColor,
  //           ),
  //           SizedBox(width: 10),
  //           Text(
  //             skill['name'],
  //             style: TextStyle(
  //               color: isSelected
  //                   ? Colors.white
  //                   : AppColors.textPrimaryColor(context),
  //               fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
  //               fontSize: 14,
  //             ),
  //           ),
  //           if (isSelected) ...[
  //             SizedBox(width: 8),
  //             Icon(Icons.check_circle, color: Colors.white, size: 18),
  //           ],
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildEmptyWorkState() {
  //   return GestureDetector(
  //     onTap: _pickWorkImages,
  //     child: Container(
  //       padding: EdgeInsets.all(20),
  //       height: 200,
  //       decoration: BoxDecoration(
  //         gradient: LinearGradient(
  //           colors: [
  //             AppColors.primaryColor.withValues(alpha: 0.05),
  //             AppColors.secondaryColor.withValues(alpha: 0.03),
  //           ],
  //         ),
  //         borderRadius: BorderRadius.circular(20),
  //         border: Border.all(
  //           color: AppColors.primaryColor.withValues(alpha: 0.3),
  //           width: 2,
  //           style: BorderStyle.solid,
  //         ),
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Container(
  //             padding: EdgeInsets.all(20),
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [
  //                   AppColors.primaryColor.withValues(alpha: 0.1),
  //                   AppColors.secondaryColor.withValues(alpha: 0.05),
  //                 ],
  //               ),
  //               shape: BoxShape.circle,
  //             ),
  //             child: Icon(
  //               Icons.add_photo_alternate,
  //               size: 50,
  //               color: AppColors.primaryColor,
  //             ),
  //           ),
  //           SizedBox(height: 16),
  //           Text(
  //             'Add Work Photos',
  //             style: TextStyle(
  //               color: AppColors.primaryColor,
  //               fontSize: 16,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //           SizedBox(height: 8),
  //           Text(
  //             'Up to 10 photos',
  //             style: TextStyle(
  //               color: AppColors.textSecondaryColor(context),
  //               fontSize: 13,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildWorkImagesGrid() {
  //   return Column(
  //     children: [
  //       // Images Count
  //       Container(
  //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //         decoration: BoxDecoration(
  //           gradient: LinearGradient(
  //             colors: [
  //               AppColors.primaryColor.withValues(alpha: 0.1),
  //               AppColors.secondaryColor.withValues(alpha: 0.05),
  //             ],
  //           ),
  //           borderRadius: BorderRadius.circular(20),
  //         ),
  //         child: Row(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             Icon(Icons.image, color: AppColors.primaryColor, size: 20),
  //             SizedBox(width: 8),
  //             Text(
  //               '${_workImages.length} / 10 photos added',
  //               style: TextStyle(
  //                 color: AppColors.primaryColor,
  //                 fontWeight: FontWeight.w600,
  //                 fontSize: 14,
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),

  //       SizedBox(height: 20),

  //       Expanded(
  //         child: SingleChildScrollView(
  //           child: Wrap(
  //             spacing: 10,
  //             runSpacing: 8,
  //             alignment: WrapAlignment.center,
  //             children: GlobalVariables.availableSkills.map((skill) {
  //               final isSelected = _selectedSkills.any(
  //                 (s) => s['name'] == skill['name'],
  //               );
  //               return _buildCompactSkillChip(skill, isSelected);
  //             }).toList(),
  //           ),
  //         ),
  //       ),

  //       // Grid
  //       GridView.builder(
  //         shrinkWrap: true,
  //         physics: NeverScrollableScrollPhysics(),
  //         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  //           crossAxisCount: 3,
  //           crossAxisSpacing: 3,
  //           mainAxisSpacing: 3,
  //         ),
  //         itemCount: _workImages.length < 10
  //             ? _workImages.length + 1
  //             : _workImages.length,
  //         itemBuilder: (context, index) {
  //           if (index == _workImages.length && _workImages.length < 10) {
  //             return _buildAddMoreButton();
  //           }

  //           return _buildWorkImageCard(_workImages[index], index);
  //         },
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildAddMoreButton() {
  //   return GestureDetector(
  //     onTap: _pickWorkImages,
  //     child: Container(
  //       decoration: BoxDecoration(
  //         gradient: LinearGradient(
  //           colors: [
  //             AppColors.primaryColor.withValues(alpha: 0.1),
  //             AppColors.secondaryColor.withValues(alpha: 0.05),
  //           ],
  //         ),
  //         borderRadius: BorderRadius.circular(16),
  //         border: Border.all(
  //           color: AppColors.primaryColor.withValues(alpha: 0.3),
  //           width: 2,
  //         ),
  //       ),
  //       child: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           Icon(Icons.add, size: 32, color: AppColors.primaryColor),
  //           SizedBox(height: 4),
  //           Text(
  //             'Add More',
  //             style: TextStyle(
  //               color: AppColors.primaryColor,
  //               fontSize: 12,
  //               fontWeight: FontWeight.w600,
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildWorkImageCard(File image, int index) {
  //   final hasUploadedUrl = _uploadedWorkUrls.length > index;
  //   return Stack(
  //     children: [
  //       Container(
  //         decoration: BoxDecoration(
  //           borderRadius: BorderRadius.circular(16),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withValues(alpha: 0.1),
  //               blurRadius: 8,
  //               offset: Offset(0, 4),
  //             ),
  //           ],
  //         ),
  //         child: ClipRRect(
  //           borderRadius: BorderRadius.circular(16),
  //           child: hasUploadedUrl
  //               ? Image.network(_uploadedWorkUrls[index]) // ✅ Uploaded
  //               : Image.file(image), // ✅ Preview
  //         ),
  //       ),
  //       Positioned(
  //         top: 6,
  //         right: 6,
  //         child: GestureDetector(
  //           onTap: () {
  //             setState(() => _workImages.removeAt(index));
  //           },
  //           child: Container(
  //             padding: EdgeInsets.all(6),
  //             decoration: BoxDecoration(
  //               gradient: LinearGradient(
  //                 colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
  //               ),
  //               shape: BoxShape.circle,
  //               boxShadow: [
  //                 BoxShadow(
  //                   color: Colors.red.withValues(alpha: 0.4),
  //                   blurRadius: 8,
  //                   offset: Offset(0, 2),
  //                 ),
  //               ],
  //             ),
  //             child: Icon(Icons.close, size: 16, color: Colors.white),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  // Widget _buildTestUploadButton() {
  //   return ElevatedButton(
  //     onPressed: () async {
  //       print('🧪 TESTING CLOUDINARY UPLOAD...');

  //       try {
  //         // Test 1: Check if service is loaded
  //         print('📋 Test 1: Service loaded?');
  //         print('   Cloud Name: ${_cloudinaryService.cloudName}');
  //         print('   Upload Preset: ${_cloudinaryService.uploadPreset}');

  //         // Test 2: Pick an image
  //         print('📋 Test 2: Picking test image...');
  //         final testImage = await _cloudinaryService.pickImage();

  //         if (testImage == null) {
  //           print('❌ No image picked');
  //           return;
  //         }

  //         print('✅ Image picked: ${testImage.path}');
  //         print('   File exists: ${await testImage.exists()}');
  //         print('   File size: ${await testImage.length()} bytes');

  //         // Test 3: Try uploading
  //         print('📋 Test 3: Attempting upload...');
  //         final url = await _cloudinaryService.uploadImage(
  //           imageFile: testImage,
  //           folder: 'test_uploads',
  //           publicId: 'test_${DateTime.now().millisecondsSinceEpoch}',
  //         );

  //         if (url != null) {
  //           print('✅✅✅ SUCCESS! Upload worked!');
  //           print('🔗 URL: $url');
  //           Get.snackbar(
  //             'Success!',
  //             'Upload test passed! URL: $url',
  //             backgroundColor: Colors.green,
  //             colorText: Colors.white,
  //             duration: Duration(seconds: 5),
  //           );
  //         } else {
  //           print('❌ Upload returned null');
  //           Get.snackbar(
  //             'Failed',
  //             'Upload returned null - check console for errors',
  //             backgroundColor: Colors.red,
  //             colorText: Colors.white,
  //           );
  //         }
  //       } catch (e, stack) {
  //         print('❌ TEST FAILED: $e');
  //         print('Stack trace: $stack');
  //         Get.snackbar(
  //           'Error',
  //           'Test failed: $e',
  //           backgroundColor: Colors.red,
  //           colorText: Colors.white,
  //         );
  //       }
  //     },
  //     child: Text('🧪 Test Cloudinary Upload'),
  //   );
  // }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        // Back Button
        if (_currentStep > 0)
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.secondaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() => _currentStep--);
                  },
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          color: AppColors.primaryColor,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        if (_currentStep > 0) SizedBox(width: 12),

        // Continue/Complete
        Expanded(
          flex: _currentStep > 0 ? 2 : 1,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryColor, AppColors.secondaryColor],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (_currentStep < 3) {
                    setState(() => _currentStep++);
                  } else {
                    _saveProfile();
                  }
                },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentStep == 3 ? 'Complete Profile' : 'Continue',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        _currentStep == 3
                            ? Icons.check_circle
                            : Icons.arrow_forward,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Custom Painter for Background Pattern (same as HandymanProfilePage)
class CirclePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

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

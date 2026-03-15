import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/controllers/handyman_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Handyman profile edit screen.
///
/// Allows a handyman to update their profile information including
/// name, phone, city, hourly rate, category, and experience.
class HandymanProfileEditScreen extends StatefulWidget {
  const HandymanProfileEditScreen({super.key});

  @override
  State<HandymanProfileEditScreen> createState() =>
      _HandymanProfileEditScreenState();
}

class _HandymanProfileEditScreenState extends State<HandymanProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _rateController = TextEditingController();
  final _experienceController = TextEditingController();

  String _selectedCategory = 'Plumbing';
  bool _isSubmitting = false;

  static const List<String> _categories = [
    'Plumbing',
    'Electrical Work',
    'Carpentry',
    'Painting',
    'Cleaning',
    'AC Repair',
    'Gardening',
    'Appliance Repair',
    'General Maintenance',
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  void _loadExistingProfile() {
    try {
      final controller = Get.find<HandymanController>();
      final profile = controller.currentHandymanProfile.value;
      if (profile != null) {
        _nameController.text = profile.name;
        _phoneController.text = profile.phone;
        _cityController.text = profile.city;
        _rateController.text = profile.hourlyRate.toStringAsFixed(0);
        _experienceController.text = profile.experience;
        if (_categories.contains(profile.category)) {
          _selectedCategory = profile.category;
        }
        setState(() {});
      }
    } catch (_) {
      // Controller may not be registered yet
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _rateController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final controller = Get.find<HandymanController>();
      final success = await controller.updateProfile({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
        'hourlyRate':
            double.tryParse(_rateController.text.trim()) ?? 0.0,
        'experience': _experienceController.text.trim(),
        'category': _selectedCategory,
      });

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimaryColor(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              icon: Icons.person_outline,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '+212 6XX XXX XXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Phone number is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _cityController,
              label: 'City',
              hint: 'e.g., Casablanca',
              icon: Icons.location_city_outlined,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'City is required';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category dropdown
            Text(
              'Service Category',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.inputBorderColor(context)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: AppColors.cardColor(context),
                  style: TextStyle(
                    color: AppColors.textPrimaryColor(context),
                    fontSize: 15,
                  ),
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedCategory = val);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _rateController,
              label: 'Hourly Rate (DH)',
              hint: 'e.g., 150',
              icon: Icons.attach_money_outlined,
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Hourly rate is required';
                }
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildField(
              controller: _experienceController,
              label: 'Experience',
              hint: 'e.g., 5 years',
              icon: Icons.work_outline,
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            color: AppColors.textPrimaryColor(context),
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: AppColors.textHintColor(context)),
            prefixIcon:
                Icon(icon, color: AppColors.primaryColor, size: 20),
            filled: true,
            fillColor: AppColors.inputFillColor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.inputBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.inputBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: AppColors.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

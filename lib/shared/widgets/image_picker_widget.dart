import 'dart:io';

import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// A reusable image picker widget that shows a bottom sheet
/// with camera and gallery options.
class ImagePickerWidget extends StatelessWidget {
  final void Function(File image) onImageSelected;
  final double size;
  final String? currentImageUrl;
  final Widget? placeholder;

  const ImagePickerWidget({
    super.key,
    required this.onImageSelected,
    this.size = 120,
    this.currentImageUrl,
    this.placeholder,
  });

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      onImageSelected(File(pickedFile.path));
    }
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Select Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: AppColors.primaryColor,
                  ),
                ),
                title: Text('Camera'),
                onTap: () => _pickImage(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppColors.primaryColor,
                  ),
                ),
                title: Text('Gallery'),
                onTap: () => _pickImage(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPickerOptions(context),
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.grey200Color(context),
              border: Border.all(
                color: AppColors.primaryColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: currentImageUrl != null && currentImageUrl!.isNotEmpty
                  ? Image.network(
                      currentImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultPlaceholder(),
                    )
                  : placeholder ?? _defaultPlaceholder(),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceColor(context),
                  width: 2,
                ),
              ),
              child: Icon(Icons.camera_alt, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultPlaceholder() {
    return Icon(Icons.person, size: size * 0.5, color: AppColors.grey400);
  }
}

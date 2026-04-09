// lib/services/service_locator.dart
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';

class ServiceLocator {
  static void init() {
    if (kDebugMode) debugPrint('Initializing services...');

    Get.lazyPut<CloudinaryService>(
      () => CloudinaryService(
        cloudName: AppConfig.cloudinaryCloudName,
        uploadPreset: AppConfig.cloudinaryUploadPreset,
      ),
      fenix: true,
    );

    Get.lazyPut<FirebaseImageService>(
      () => FirebaseImageService(),
      fenix: true,
    );

    if (kDebugMode) debugPrint('Services initialized');
  }
}

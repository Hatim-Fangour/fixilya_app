// lib/services/service_locator.dart
import 'package:get/get.dart';
import 'package:fixilya_app/services/cloudinary_service.dart';
import 'package:fixilya_app/services/firebase_image_service.dart';

class ServiceLocator {
  static void init() {
    print('🔧 Initializing services...');

    // ✅ Initialize Cloudinary Service as singleton
    Get.lazyPut<CloudinaryService>(
      () => CloudinaryService(
        cloudName: 'dbz3wtlbj', // ✅ Your REAL cloud name
        uploadPreset: 'fixilya_app', // ✅ Your REAL upload preset
      ),
      fenix: true, // Keeps instance alive
    );

    // ✅ Initialize Firebase Image Service as singleton
    Get.lazyPut<FirebaseImageService>(
      () => FirebaseImageService(),
      fenix: true,
    );

    print('✅ Services initialized successfully');
    print('   📦 CloudinaryService ready');
    print('   📦 FirebaseImageService ready');
  }
}

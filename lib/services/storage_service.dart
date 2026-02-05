import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // ✅ CRITICAL: Lock to prevent multiple concurrent image picker calls
  static bool _isPickerActive = false;

  // Pick image from gallery or camera
  Future<File?> pickImage({bool fromCamera = false}) async {
    // ✅ Check if picker is already active
    if (_isPickerActive) {
      print('⚠️ Image picker is already active');
      return null;
    }

    try {
      // ✅ Set lock
      _isPickerActive = true;

      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    } finally {
      // ✅ Always release lock
      _isPickerActive = false;
    }
  }

  // Pick multiple images
  Future<List<File>> pickMultipleImages({int maxImages = 10}) async {
    // ✅ FIX: Check if picker is already active
    if (_isPickerActive) {
      print('⚠️ Image picker is already active');
      return [];
    }

    try {
      // ✅ FIX: Set lock
      _isPickerActive = true;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (images.length > maxImages) {
        print('⚠️ Selected ${images.length} images, limiting to $maxImages');
        return images.take(maxImages).map((xFile) => File(xFile.path)).toList();
      }

      return images.map((xFile) => File(xFile.path)).toList();
    } catch (e) {
      print('❌ Error picking multiple images: $e');
      return [];
    } finally {
      // ✅ FIX: Always release lock
      _isPickerActive = false;
    }
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // === VALIDATION ===

      // 1. Check file exists
      if (!await imageFile.exists()) {
        print('❌ File does not exist: ${imageFile.path}');
        throw Exception('File does not exist on device');
      }

      // 2. Check file size
      final fileSize = await imageFile.length();
      print('📁 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize == 0) {
        throw Exception('File is empty (0 bytes)');
      }

      if (fileSize > 10 * 1024 * 1024) {
        // 10 MB limit
        throw Exception('File too large (max 10MB)');
      }

      // 3. Verify file is readable
      try {
        await imageFile.readAsBytes();
      } catch (e) {
        print('❌ Cannot read file: $e');
        throw Exception('Cannot read file: $e');
      }

      // === UPLOAD ===

      final String fileName =
          'profile_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('profiles/$fileName');

      print('📤 Starting upload to: profiles/$fileName');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);

      // Track progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('📤 Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Profile picture uploaded successfully!');
      print('🔗 URL: $downloadUrl');

      // ✅ Clean up temp file
      try {
        if (imageFile.path.contains('app_flutter')) {
          await imageFile.delete();
          print('🗑️ Temp file cleaned up');
        }
      } catch (e) {
        print('⚠️ Could not delete temp file: $e');
      }

      return downloadUrl;
    } on FirebaseException catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ FIREBASE ERROR');
      print('Code: ${e.code}');
      print('Message: ${e.message}');
      print('File path: ${imageFile.path}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (e.code == 'object-not-found') {
        print('⚠️ object-not-found during upload usually means:');
        print('  • File was deleted before upload completed');
        print('  • File path is invalid or temporary');
        print('  • Permission issue reading the file');
      }

      return null;
    } catch (e, stackTrace) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ UPLOAD ERROR');
      print('Error: $e');
      print('File: ${imageFile.path}');
      print('Stack: $stackTrace');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return null;
    }
  }

  // Upload work images (batch upload)
  Future<List<String>> uploadWorkImages({
    required String userId,
    required List<File> images,
    Function(int current, int total)? onProgress,
  }) async {
    List<String> downloadUrls = [];

    try {
      for (int i = 0; i < images.length; i++) {
        final imageFile = images[i];

        // Validate each file
        if (!await imageFile.exists()) {
          print('⚠️ File $i does not exist, skipping');
          if (onProgress != null) onProgress(i + 1, images.length);
          continue;
        }

        final fileSize = await imageFile.length();
        if (fileSize == 0) {
          print('⚠️ File $i is empty, skipping');
          if (onProgress != null) onProgress(i + 1, images.length);
          continue;
        }

        // Upload
        final String fileName =
            'work_${userId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        final Reference ref = _storage.ref().child('work_images/$fileName');

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'index': i.toString(),
            'totalImages': images.length.toString(),
          },
        );

        final UploadTask uploadTask = ref.putFile(imageFile, metadata);
        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        downloadUrls.add(downloadUrl);

        // Call progress callback
        if (onProgress != null) {
          onProgress(i + 1, images.length);
        }

        print('✅ Work image ${i + 1}/${images.length} uploaded');

        // Clean up temp file
        try {
          if (imageFile.path.contains('app_flutter')) {
            await imageFile.delete();
          }
        } catch (e) {
          print('⚠️ Could not delete temp file: $e');
        }
      }

      return downloadUrls;
    } catch (e) {
      print('❌ Error uploading work images: $e');
      return downloadUrls; // Return what we managed to upload
    }
  }

  // Upload single work image
  Future<String?> uploadWorkImage({
    required String userId,
    required File imageFile,
  }) async {
    try {
      // Validate
      if (!await imageFile.exists()) {
        throw Exception('File does not exist');
      }

      final String fileName =
          'work_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = _storage.ref().child('work_images/$fileName');

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'userId': userId},
      );

      final UploadTask uploadTask = ref.putFile(imageFile, metadata);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ Work image uploaded: $downloadUrl');

      // Clean up
      try {
        if (imageFile.path.contains('app_flutter')) {
          await imageFile.delete();
        }
      } catch (e) {}

      return downloadUrl;
    } catch (e) {
      print('❌ Error uploading work image: $e');
      return null;
    }
  }

  // Delete image
  Future<bool> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty ||
          !imageUrl.contains('firebasestorage.googleapis.com')) {
        return false;
      }

      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      print('✅ Image deleted: $imageUrl');
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') {
        print('ℹ️ Image already deleted: $imageUrl');
        return true; // Already deleted
      }
      print('❌ Error deleting image: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return false;
    }
  }

  // Delete multiple images
  Future<int> deleteImages(List<String> imageUrls) async {
    int deletedCount = 0;

    for (String url in imageUrls) {
      bool deleted = await deleteImage(url);
      if (deleted) deletedCount++;
    }

    print('✅ Deleted $deletedCount/${imageUrls.length} images');
    return deletedCount;
  }

  // Check if picker is currently active (useful for UI state)
  bool get isPickerActive => _isPickerActive;

  // ✅ NEW: Force reset picker lock (use only if picker gets stuck)
  static void resetPickerLock() {
    _isPickerActive = false;
    print('⚠️ Picker lock manually reset');
  }
}

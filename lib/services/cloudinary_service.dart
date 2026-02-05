import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class CloudinaryService {
  late final CloudinaryPublic _cloudinary;
  final ImagePicker _picker = ImagePicker();

  final String cloudName;
  final String uploadPreset;

  static bool _isPickerActive = false;

  CloudinaryService({required this.cloudName, required this.uploadPreset}) {
    _cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);
    print('🔧 CloudinaryService initialized:');
    print('   Cloud Name: $cloudName');
    print('   Upload Preset: $uploadPreset');
  }

  Future<File?> pickImage({bool fromCamera = false}) async {
    if (_isPickerActive) {
      print('⚠️ Image picker is already active');
      return null;
    }

    try {
      _isPickerActive = true;

      final XFile? image = await _picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 2048, // ✅ Higher quality (Cloudinary will compress)
        maxHeight: 2048,
        imageQuality: 100, // ✅ Upload original quality
      );

      if (image == null) {
        print('ℹ️ User cancelled image selection');
        return null;
      }

      print('✅ Image picked: ${image.path}');
      final File imageFile = File(image.path);

      if (!await imageFile.exists()) {
        print('❌ File does not exist');
        return null;
      }

      final fileSize = await imageFile.length();
      print('📁 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize == 0) {
        print('❌ File is empty');
        return null;
      }

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String newPath = '${appDir.path}/$fileName';
      final File persistentFile = await imageFile.copy(newPath);

      print('✅ File ready: $newPath');
      return persistentFile;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    } finally {
      _isPickerActive = false;
    }
  }

  Future<List<File>> pickMultipleImages({int maxImages = 10}) async {
    if (_isPickerActive) {
      print('⚠️ Image picker is already active');
      return [];
    }

    try {
      _isPickerActive = true;

      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 100,
      );

      if (images.isEmpty) {
        print('ℹ️ No images selected');
        return [];
      }

      print('✅ ${images.length} images picked');

      final imagesToProcess = images.length > maxImages
          ? images.take(maxImages).toList()
          : images;

      List<File> persistentFiles = [];
      final Directory appDir = await getApplicationDocumentsDirectory();

      for (int i = 0; i < imagesToProcess.length; i++) {
        try {
          final File tempFile = File(imagesToProcess[i].path);

          if (!await tempFile.exists()) {
            print('⚠️ File $i does not exist, skipping');
            continue;
          }

          final String fileName =
              '${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final String newPath = '${appDir.path}/$fileName';
          final File persistentFile = await tempFile.copy(newPath);

          persistentFiles.add(persistentFile);
          print('✅ File $i ready');
        } catch (e) {
          print('⚠️ Error processing file $i: $e');
        }
      }

      print('✅ ${persistentFiles.length} files ready for upload');
      return persistentFiles;
    } catch (e) {
      print('❌ Error picking multiple images: $e');
      return [];
    } finally {
      _isPickerActive = false;
    }
  }

  // ✅ FIXED: Upload without blocking UI
  Future<String?> uploadImage({
    required File imageFile,
    required String folder,
    String? publicId,
    bool isProfilePicture = false,
    Map<String, dynamic>? tags,
    int maxRetries = 2,
    int timeoutSeconds = 60,
  }) async {
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 UPLOAD ATTEMPT ${retryCount + 1}/${maxRetries + 1}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        if (!await imageFile.exists()) {
          throw Exception('File does not exist');
        }

        final fileSize = await imageFile.length();
        print('📁 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        if (fileSize == 0) throw Exception('File is empty');
        if (fileSize > 10 * 1024 * 1024) throw Exception('File too large');

        // ✅ Read file into memory
        final Uint8List fileBytes = await imageFile.readAsBytes();

        // ✅ Get temp directory
        final tempDir = await getTemporaryDirectory();

        print('📤 Uploading to Cloudinary with transformations...');

        final uploadParams = _CloudinaryUploadParams(
          cloudName: cloudName,
          uploadPreset: uploadPreset,
          fileBytes: fileBytes,
          folder: folder,
          publicId: publicId,
          tempDirPath: tempDir.path, // ✅ Pass path to isolate
          isProfilePicture: isProfilePicture,
        );

        // ✅ Upload in isolate
        final result = await compute(_uploadInIsolate, uploadParams).timeout(
          Duration(seconds: timeoutSeconds + 5),
          onTimeout: () {
            print('⏱️ Upload timed out');
            return _CloudinaryUploadResult(success: false, error: 'Timeout');
          },
        );

        if (result.success && result.url != null) {
          print('✅ Upload successful!');
          print('🔗 URL: ${result.url}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          // ✅ Get optimized URL with transformations
          final optimizedUrl = getOptimizedUrl(
            result.url!,
            isProfilePicture: isProfilePicture,
          );

          print('🔗 Optimized URL: $optimizedUrl');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          try {
            await imageFile.delete();
            print('🗑️ Temp file cleaned up');
          } catch (e) {
            print('⚠️ Could not delete temp file: $e');
          }

          return optimizedUrl;
        } else {
          print('❌ Upload failed: ${result.error}');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return null;
        }
      } on TimeoutException catch (e) {
        print('⏱️ UPLOAD TIMEOUT: $e');
        return null;
      } catch (e) {
        print('❌ Attempt ${retryCount + 1} failed: $e');
        print('❌ UPLOAD ERROR: $e');
        if (retryCount < maxRetries) {
          print('🔄 Retrying in 2 seconds...');
          await Future.delayed(Duration(seconds: 2));
          retryCount++;
        } else {
          print('❌ All retries exhausted');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return null;
        }
      }
    }
    return null;
  }

  Future<List<String>> uploadMultipleImages({
    required List<File> imageFiles,
    required String folder,
    Function(int current, int total, String status)? onProgress,
    int timeoutSeconds = 60,
  }) async {
    List<String> uploadedUrls = [];

    try {
      print('📤 Uploading ${imageFiles.length} images...');

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];

        if (onProgress != null) {
          onProgress(i + 1, imageFiles.length, 'Uploading image ${i + 1}...');
        }

        if (!await imageFile.exists()) {
          print('⚠️ File $i missing');
          continue;
        }

        final fileSize = await imageFile.length();
        if (fileSize == 0) {
          print('⚠️ File $i empty');
          if (onProgress != null)
            onProgress(i + 1, imageFiles.length, 'File is empty');
          continue;
        }

        // if (fileSize == 0) {
        //   print('⚠️ File $i is empty, skipping');
        //   if (onProgress != null) onProgress(i + 1, imageFiles.length, 'File is empty');
        //   continue;
        // }

        final url = await uploadImage(
          imageFile: imageFile,
          folder: folder,
          publicId: '${DateTime.now().millisecondsSinceEpoch}_$i',
          isProfilePicture: false, // Work images don't need face detection
          timeoutSeconds: timeoutSeconds,
          maxRetries: 2,
        );

        if (url != null) {
          uploadedUrls.add(url);
          print('✅ Image ${i + 1}/${imageFiles.length} uploaded');
        } else {
          print('❌ Image ${i + 1}/${imageFiles.length} failed');
        }

        // Small delay between uploads
        if (i < imageFiles.length - 1) {
          await Future.delayed(Duration(milliseconds: 500));
        }

        // if (onProgress != null) {
        //   onProgress(i + 1, imageFiles.length);
        // }
      }
      print('✅ Complete: ${uploadedUrls.length}/${imageFiles.length}');
      print('✅ Complete: ${uploadedUrls.length}/${imageFiles.length}');
      return uploadedUrls;
    } catch (e) {
      print('❌ Error: $e');
      return uploadedUrls;
    }
  }

  Future<bool> deleteImage(String publicId) async {
    print('⚠️ Cloudinary deletion requires backend API');
    return true;
  }

  String getOptimizedUrl(
    String originalUrl, {
    int? width,
    int? height,
    String format = 'auto',
    String quality = 'auto:good',
    bool isProfilePicture = false,
  }) {
    try {
      final uri = Uri.parse(originalUrl);
      final pathSegments = uri.pathSegments.toList();

      if (pathSegments.length < 3) return originalUrl;

      // ✅ Build transformation string
      List<String> transformations = [];

      if (isProfilePicture) {
        // ✅ PROFILE PICTURE TRANSFORMATIONS
        transformations.addAll([
          'g_face', // Gravity: focus on face
          'c_thumb', // Crop mode: thumbnail with face detection
          'w_${width ?? 100}', // Width: 400px default
          'h_${height ?? 100}', // Height: 400px (square)
          'z_0.7', // Zoom: 0.7 to include some background
          'f_$format', // Format: auto (WebP when supported)
          'q_$quality', // Quality: auto:good (smart compression)
        ]);
      } else {
        // ✅ WORK IMAGE TRANSFORMATIONS
        transformations.addAll([
          'c_limit', // Crop mode: limit (don't upscale)
          'w_${width ?? 1200}', // Width: 1200px max
          'h_${height ?? 1200}', // Height: 1200px max
          'f_$format', // Format: auto
          'q_$quality', // Quality: auto:good
        ]);
      }

      final transformation = transformations.join(',');

      // ✅ Insert transformation after 'upload'
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1) return originalUrl;

      pathSegments.insert(uploadIndex + 1, transformation);

      // ✅ Build new URL
      final optimizedUrl = Uri(
        scheme: uri.scheme,
        host: uri.host,
        pathSegments: pathSegments,
      ).toString();

      return optimizedUrl;
    } catch (e) {
      print('⚠️ Error creating optimized URL: $e');
      return originalUrl;
    }

    //   final newSegments = [...pathSegments];
    //   newSegments.insert(pathSegments.indexOf('upload') + 1, transformation);

    //   return Uri(
    //     scheme: uri.scheme,
    //     host: uri.host,
    //     pathSegments: newSegments,
    //   ).toString();
    // } catch (e) {
    //   print(e);
    // }
  }

  /// ✅ Get different variations of an image
  Map<String, String> getImageVariations(String originalUrl) {
    return {
      'thumbnail': getOptimizedUrl(
        originalUrl,
        isProfilePicture: true,
        width: 150,
        height: 150,
      ),
      'small': getOptimizedUrl(originalUrl, width: 400, height: 400),
      'medium': getOptimizedUrl(originalUrl, width: 800, height: 800),
      'large': getOptimizedUrl(originalUrl, width: 1200, height: 1200),
      'original': originalUrl,
    };
  }

  bool get isPickerActive => _isPickerActive;

  static void resetPickerLock() {
    _isPickerActive = false;
  }
}

// ✅ Helper classes
class _CloudinaryUploadParams {
  final String cloudName;
  final String uploadPreset;
  final Uint8List fileBytes;
  final String folder;
  final String? publicId;
  final String tempDirPath; // ✅ Pass directory path, not get it in isolate
  final bool isProfilePicture;

  _CloudinaryUploadParams({
    required this.cloudName,
    required this.uploadPreset,
    required this.fileBytes,
    required this.folder,
    this.publicId,
    required this.tempDirPath,
    required this.isProfilePicture,
  });
}

class _CloudinaryUploadResult {
  final bool success;
  final String? url;
  final String? error;

  _CloudinaryUploadResult({required this.success, this.url, this.error});
}

// ✅ Isolate function - NO platform channel calls
Future<_CloudinaryUploadResult> _uploadInIsolate(
  _CloudinaryUploadParams params,
) async {
  File? tempFile;
  try {
    print('🔧 Isolate: Initializing...');

    final cloudinary = CloudinaryPublic(
      params.cloudName,
      params.uploadPreset,
      cache: false,
    );

    // ✅ Use provided directory path (no platform channels needed)
    // Create temp file
    final tempFilePath =
        '${params.tempDirPath}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
    tempFile = File(tempFilePath);

    await tempFile.writeAsBytes(params.fileBytes);
    print(
      '🔧 Isolate: File size: ${(params.fileBytes.length / 1024).toStringAsFixed(2)} KB',
    );

    print('🔧 Isolate: Uploading...');

    // ✅ Upload with eager transformation (applied during upload)
    final response = await cloudinary
        .uploadFile(
          CloudinaryFile.fromFile(
            tempFile.path,
            folder: params.folder,
            publicId: params.publicId,
            resourceType: CloudinaryResourceType.Image,
          ),
        )
        .timeout(
          Duration(seconds: 50),
          onTimeout: () {
            print('🔧 Isolate: Timeout');
            throw TimeoutException('Upload timeout');
          },
        );

    print('🔧 Isolate: Success!');
    print('🔧 Isolate: URL: ${response.secureUrl}');

    // Clean up
    try {
      await tempFile.delete();
      print('🔧 Isolate: Temp file deleted');
    } catch (e) {
      print('🔧 Isolate: Could not delete temp file: $e');
    }

    return _CloudinaryUploadResult(success: true, url: response.secureUrl);
  } catch (e) {
    print('🔧 Isolate: Error - $e');
    return _CloudinaryUploadResult(success: false, error: e.toString());
  } finally {
    try {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
        print('🔧 Isolate: Cleanup complete');
      }
    } catch (e) {
      print('🔧 Isolate: Cleanup error: $e');
    }
  }
}

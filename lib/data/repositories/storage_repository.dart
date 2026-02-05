import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload profile image
  Future<String> uploadProfileImage({
    required String userId,
    required File file,
  }) async {
    final ref = _storage.ref().child(
      'profiles/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Upload portfolio image
  Future<String> uploadPortfolioImage({
    required String handymanId,
    required File file,
  }) async {
    final ref = _storage.ref().child(
      'portfolio/$handymanId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Upload booking attachment
  Future<String> uploadBookingAttachment({
    required String bookingId,
    required File file,
  }) async {
    final fileName = file.path.split('/').last;
    final ref = _storage.ref().child('bookings/$bookingId/$fileName');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Delete file
  Future<void> deleteFile(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }

  // Get file metadata
  Future<FullMetadata> getFileMetadata(String url) async {
    final ref = _storage.refFromURL(url);
    return await ref.getMetadata();
  }
}

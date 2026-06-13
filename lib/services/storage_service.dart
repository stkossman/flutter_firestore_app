import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService({
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ??
            FirebaseStorage.instanceFor(
              bucket: 'flutter-notes-dac16.firebasestorage.app',
            );

  static const int maxImageSizeBytes = 5 * 1024 * 1024;

  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String? lastUploadedPath;

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated. Please sign in first.');
    }
    return user;
  }

  Future<String> uploadNoteImageWithProgress(
    File imageFile,
    String noteId,
    void Function(double progress) onProgress,
  ) async {
    final user = _requireUser();
    final size = await imageFile.length();
    if (size > maxImageSizeBytes) {
      throw StateError('Image must be smaller than 5 MB.');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'users/${user.uid}/notes/$noteId/image_$timestamp.jpg';
    final ref = _storage.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {
        'userId': user.uid,
        'noteId': noteId,
        'uploadedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );

    final uploadTask = ref.putFile(imageFile, metadata);
    final subscription = uploadTask.snapshotEvents.listen((snapshot) {
      final totalBytes = snapshot.totalBytes;
      if (totalBytes > 0) {
        onProgress(snapshot.bytesTransferred / totalBytes);
      }
    });

    try {
      await uploadTask;
      final downloadUrl = await ref.getDownloadURL();
      lastUploadedPath = storagePath;
      onProgress(1);
      return downloadUrl;
    } on FirebaseException catch (error) {
      if (error.code == 'unauthorized') {
        throw StateError(
          'Storage permission denied. Check Firebase Storage Rules.',
        );
      }
      throw StateError(error.message ?? 'Image upload failed.');
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> deleteNoteImage(String imageUrl) async {
    if (imageUrl.trim().isEmpty) {
      return;
    }
    await _storage.refFromURL(imageUrl).delete();
  }

  Future<void> deleteNoteImageByPath(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return;
    }
    await _storage.ref(storagePath).delete();
  }

  Future<Map<String, String?>> getImageMetadata(String imageUrl) async {
    final metadata = await _storage.refFromURL(imageUrl).getMetadata();
    return {
      'contentType': metadata.contentType,
      'userId': metadata.customMetadata?['userId'],
      'noteId': metadata.customMetadata?['noteId'],
      'uploadedAt': metadata.customMetadata?['uploadedAt'],
    };
  }
}

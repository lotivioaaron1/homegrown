// lib/services/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Handles profile photo uploads to Firebase Storage. Kept separate
/// from NotificationService/Firestore logic since this is a
/// different Firebase product with its own SDK and rules.
class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Uploads a profile photo for [uid], overwriting any previous one
  /// at the same path (so storage doesn't accumulate old photos
  /// every time someone changes their picture). Returns the
  /// downloadable URL to save on the user's Firestore doc.
  static Future<String> uploadProfilePhoto(String uid, File file) async {
    final ref = _storage.ref().child('profile_photos/$uid/photo.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
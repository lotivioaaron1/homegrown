// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
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

  /// Uploads an organizer's optional proof-of-legitimacy photo (a barangay
  /// certificate, business permit, or similar) for a super-admin to review
  /// before approving them — see admin_review_screen.dart. Overwrites any
  /// previous submission, same as the profile photo above.
  static Future<void> uploadOrganizerVerificationDoc(String uid, File file) async {
    final ref = _storage.ref().child('organizer_verification/$uid/document.jpg');
    await ref.putFile(file);
  }

  /// Fetches an organizer's verification photo as raw bytes for the admin
  /// review screen. Deliberately NOT `getDownloadURL()`: that issues a
  /// token-bearing public URL that bypasses Storage rules for anyone who
  /// gets hold of it, which is wrong for a document that can contain a
  /// government ID. `getData()` goes through the SDK and is checked against
  /// storage.rules on every call, so only the owner or an admin ever
  /// actually succeeds. Returns null if nothing was ever uploaded.
  static Future<Uint8List?> fetchOrganizerVerificationDoc(String uid) async {
    final ref = _storage.ref().child('organizer_verification/$uid/document.jpg');
    try {
      return await ref.getData(10 * 1024 * 1024);
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return null;
      rethrow;
    }
  }
}
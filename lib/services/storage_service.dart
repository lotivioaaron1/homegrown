// lib/services/storage_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Handles profile photo uploads to Firebase Storage. Kept separate
/// from NotificationService/Firestore logic since this is a
/// different Firebase product with its own SDK and rules.
class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Deliberately below the 10 MB ceiling in storage.rules. A file that passes
  /// here can never be rejected by the rules, so users get this class's plain
  /// message instead of an opaque permission error from the SDK.
  static const int maxUploadBytes = 5 * 1024 * 1024;

  /// Compresses to JPEG at the same settings MediaService uses for portfolio
  /// photos. Storage bills for what is stored and again for every download, so
  /// an uncompressed 12 MP camera shot is a recurring cost for an image that is
  /// only ever displayed as a small avatar.
  static Future<Uint8List> _compress(File file, {required String label}) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 1920,
      minHeight: 1920,
      quality: 80,
      format: CompressFormat.jpeg,
    );

    if (bytes == null) {
      throw StorageException('Could not process that image. Try another one.');
    }
    if (bytes.lengthInBytes > maxUploadBytes) {
      final mb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      throw StorageException(
          '$label is still $mb MB after compression. Max is 5 MB.');
    }
    return bytes;
  }

  /// Uploads a profile photo for [uid], overwriting any previous one
  /// at the same path (so storage doesn't accumulate old photos
  /// every time someone changes their picture). Returns the
  /// downloadable URL to save on the user's Firestore doc.
  static Future<String> uploadProfilePhoto(String uid, File file) async {
    final bytes = await _compress(file, label: 'Photo');
    final ref = _storage.ref().child('profile_photos/$uid/photo.jpg');
    // The explicit content type matters: without it Storage stores the object
    // as application/octet-stream, which some browsers download instead of
    // rendering when the URL is opened directly.
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  /// Uploads an organizer's optional proof-of-legitimacy photo (a barangay
  /// certificate, business permit, or similar) for a super-admin to review
  /// before approving them — see admin_review_screen.dart. Overwrites any
  /// previous submission, same as the profile photo above.
  static Future<void> uploadOrganizerVerificationDoc(
      String uid, File file) async {
    final bytes = await _compress(file, label: 'Document');
    final ref = _storage.ref().child('organizer_verification/$uid/document.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
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

/// Carries copy already written for users, so `friendlyError` passes the
/// message through rather than flattening it to the generic sentence.
class StorageException implements Exception {
  final String message;
  StorageException(this.message);

  @override
  String toString() => 'StorageException: $message';
}

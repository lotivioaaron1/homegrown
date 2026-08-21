// lib/services/media_service.dart
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/media_item.dart';

/// Thrown for expected, user-facing problems (too large, unreadable image).
/// Lets the UI show a clean message instead of a raw exception string.
class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => message;
}

/// Portfolio media (photos in Phase 2, videos in Phase 3). Kept separate
/// from StorageService, which only handles the single profile avatar.
class MediaService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  static const int maxPhotoBytes = 5 * 1024 * 1024; // 5 MB

  static CollectionReference<Map<String, dynamic>> _mediaCol(String uid) =>
      _db.collection('users').doc(uid).collection('media');

  /// Live list of a user's media, newest first, optionally filtered by type.
  static Stream<List<MediaItem>> streamMedia(String uid, {MediaType? type}) {
    Query<Map<String, dynamic>> q =
        _mediaCol(uid).orderBy('createdAt', descending: true);
    if (type != null) q = q.where('type', isEqualTo: type.name);
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => MediaItem.fromMap(d.id, d.data())).toList());
  }

  /// Picks one gallery image, compresses to JPEG (~1920px, quality 80),
  /// validates the final size, uploads to Storage, and writes the Firestore
  /// doc. Returns the created item, or null if the user cancelled the picker.
  static Future<MediaItem?> pickAndUploadPhoto({
    required String uid,
    required MediaCategory category,
    String caption = '',
  }) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400, // rough pre-cap before compression does the real work
    );
    if (picked == null) return null;

    final Uint8List? bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 1920,
      minHeight: 1920,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    if (bytes == null) {
      throw MediaException('Could not process that image. Try another one.');
    }
    if (bytes.lengthInBytes > maxPhotoBytes) {
      final mb = (bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      throw MediaException(
          'Image is still $mb MB after compression. Max is 5 MB.');
    }

    final mediaId = _uuid.v4();
    final ref = _storage.ref('profile_media/$uid/$mediaId.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    final item = MediaItem(
      id: mediaId,
      type: MediaType.photo,
      url: url,
      thumbnailUrl: url, // grid uses memCacheWidth for lightweight thumbs
      category: category,
      caption: caption,
      createdAt: DateTime.now(),
      sizeBytes: bytes.lengthInBytes,
    );
    await _mediaCol(uid).doc(mediaId).set(item.toMap());
    return item;
  }

  /// Deletes the Storage object (best-effort) and the Firestore doc.
  static Future<void> deleteMedia(String uid, MediaItem item) async {
    try {
      final ext = item.type == MediaType.video ? 'mp4' : 'jpg';
      await _storage.ref('profile_media/$uid/${item.id}.$ext').delete();
    } catch (_) {
      // Object may already be gone; the Firestore delete below is what matters.
    }
    await _mediaCol(uid).doc(item.id).delete();
  }
}
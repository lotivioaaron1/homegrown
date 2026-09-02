// lib/services/media_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import '../models/media_item.dart';

/// Thrown for expected, user-facing problems (too large, unreadable image).
/// Lets the UI show a clean message instead of a raw exception string.
class MediaException implements Exception {
  final String message;
  MediaException(this.message);
  @override
  String toString() => message;
}

/// Which half of a video upload is currently running. Videos are slow enough
/// that an indeterminate spinner reads as a hang, so the UI names the phase
/// and shows real progress for each.
enum MediaUploadPhase { compressing, uploading }

/// Reports 0.0–1.0 progress within [phase].
typedef MediaProgress = void Function(MediaUploadPhase phase, double progress);

/// Portfolio media — photos and highlight videos. Kept separate from
/// StorageService, which only handles the single profile avatar.
class MediaService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const Uuid _uuid = Uuid();

  static const int maxPhotoBytes = 5 * 1024 * 1024; // 5 MB

  /// Per-athlete portfolio quotas. These are cost controls, not UX limits:
  /// Firebase bills egress at $0.12/GB, so an uncapped portfolio is an
  /// uncapped bill. Enforced app-side only — Firestore rules cannot count a
  /// subcollection, and the same pre-write check guards TeamService.maxPlayers.
  static const int maxPhotos = 20;
  static const int maxVideos = 3;

  /// Highlight clips are reels, not footage. 60s is the standard recruiting
  /// clip length and keeps a compressed upload near 8–12 MB.
  static const int maxVideoSeconds = 60;

  /// Matches the ceiling in storage.rules, so a file that passes here cannot
  /// then be rejected by the rules with an opaque permission error.
  static const int maxVideoBytes = 25 * 1024 * 1024;

  /// Phones report durations a few milliseconds over a round number, so a
  /// genuine 60s clip can measure 60.02s. Reject only past this grace.
  static const int _durationGraceMs = 1500;

  static CollectionReference<Map<String, dynamic>> _mediaCol(String uid) =>
      _db.collection('users').doc(uid).collection('media');

  /// How many items of [type] the user already has. Uses the count
  /// aggregation rather than fetching the docs — quota checks run before
  /// every upload, and this bills as a single read regardless of size.
  static Future<int> countOf(String uid, MediaType type) async {
    final agg =
        await _mediaCol(uid).where('type', isEqualTo: type.name).count().get();
    return agg.count ?? 0;
  }

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
    // Checked before the picker opens, not after: making someone choose a
    // photo and only then telling them the portfolio is full is a worse
    // experience than refusing up front.
    if (await countOf(uid, MediaType.photo) >= maxPhotos) {
      throw MediaException(
          'Your portfolio is full at $maxPhotos photos. Delete one to add another.');
    }

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

  /// Picks one gallery video, verifies its duration, transcodes it to ~720p,
  /// uploads the clip plus a poster-frame thumbnail, and writes the Firestore
  /// doc. Returns the created item, or null if the user cancelled the picker.
  ///
  /// [onProgress] fires through the compress phase and again through the
  /// upload phase, each running 0.0–1.0.
  static Future<MediaItem?> pickAndUploadVideo({
    required String uid,
    required MediaCategory category,
    String caption = '',
    MediaProgress? onProgress,
  }) async {
    if (await countOf(uid, MediaType.video) >= maxVideos) {
      throw MediaException(
          'You already have $maxVideos highlights. Delete one to add another.');
    }

    final picked = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
      // Honoured when recording, and by the iOS picker; Android gallery picks
      // ignore it, which is why the duration is verified again below.
      maxDuration: const Duration(seconds: maxVideoSeconds),
    );
    if (picked == null) return null;

    final info = await VideoCompress.getMediaInfo(picked.path);
    final durationMs = info.duration ?? 0;
    if (durationMs > (maxVideoSeconds * 1000) + _durationGraceMs) {
      final secs = (durationMs / 1000).round();
      throw MediaException(
          'That clip is ${_formatSeconds(secs)} long. Highlights must be '
          '$maxVideoSeconds seconds or shorter — trim it and try again.');
    }
    // Round rather than truncate so a 59.6s clip reads as 1:00, not 0:59.
    final durationSeconds = (durationMs / 1000).round();

    final mediaId = _uuid.v4();
    File? compressedFile;
    try {
      final sub = VideoCompress.compressProgress$.subscribe(
          (p) => onProgress?.call(MediaUploadPhase.compressing, p / 100));
      MediaInfo? compressed;
      try {
        compressed = await VideoCompress.compressVideo(
          picked.path,
          quality: VideoQuality.MediumQuality,
          includeAudio: true,
          // Never true: that deletes the athlete's original from their gallery.
          deleteOrigin: false,
        );
      } finally {
        sub.unsubscribe();
      }

      final path = compressed?.path;
      if (path == null) {
        throw MediaException('Could not process that video. Try another clip.');
      }
      compressedFile = File(path);

      final videoBytes = await compressedFile.length();
      if (videoBytes > maxVideoBytes) {
        final mb = (videoBytes / (1024 * 1024)).toStringAsFixed(1);
        const maxMb = maxVideoBytes ~/ (1024 * 1024);
        throw MediaException(
            'That video is still $mb MB after compression. Max is $maxMb MB — '
            'try a shorter clip.');
      }

      // Poster frame. position: -1 lets the plugin pick a representative
      // frame rather than frame zero, which is often a black fade-in.
      final Uint8List? thumbBytes =
          await VideoCompress.getByteThumbnail(path, quality: 75, position: -1);
      String thumbnailUrl = '';
      if (thumbBytes != null) {
        final thumbRef = _storage.ref(_thumbPath(uid, mediaId));
        await thumbRef.putData(
            thumbBytes, SettableMetadata(contentType: 'image/jpeg'));
        thumbnailUrl = await thumbRef.getDownloadURL();
      }

      // putFile, not putData: a 25 MB Uint8List held in memory alongside the
      // decoder is a real OOM risk on the low-end devices this app targets.
      final ref = _storage.ref(_videoPath(uid, mediaId));
      final task =
          ref.putFile(compressedFile, SettableMetadata(contentType: 'video/mp4'));
      final progressSub = task.snapshotEvents.listen((s) {
        if (s.totalBytes > 0) {
          onProgress?.call(
              MediaUploadPhase.uploading, s.bytesTransferred / s.totalBytes);
        }
      });
      try {
        await task;
      } finally {
        await progressSub.cancel();
      }
      final url = await ref.getDownloadURL();

      final item = MediaItem(
        id: mediaId,
        type: MediaType.video,
        url: url,
        // Falls back to the video URL so the grid still has something to ask
        // for if thumbnail generation failed; the tile's error widget covers
        // the case where that fails to decode as an image.
        thumbnailUrl: thumbnailUrl.isNotEmpty ? thumbnailUrl : url,
        category: category,
        caption: caption,
        createdAt: DateTime.now(),
        sizeBytes: videoBytes,
        durationSeconds: durationSeconds,
      );
      await _mediaCol(uid).doc(mediaId).set(item.toMap());
      return item;
    } finally {
      // The transcoded copy lives in a cache dir; without this it accumulates
      // on the device across every upload.
      await VideoCompress.deleteAllCache();
    }
  }

  static String _videoPath(String uid, String id) => 'profile_media/$uid/$id.mp4';
  static String _thumbPath(String uid, String id) =>
      'profile_media/$uid/${id}_thumb.jpg';

  /// Deletes the Storage object(s) (best-effort) and the Firestore doc.
  static Future<void> deleteMedia(String uid, MediaItem item) async {
    if (item.type == MediaType.video) {
      // Two objects per video — deleting only the .mp4 would orphan every
      // thumbnail in Storage, where nothing ever references it again.
      await _deleteObject(_videoPath(uid, item.id));
      await _deleteObject(_thumbPath(uid, item.id));
    } else {
      await _deleteObject('profile_media/$uid/${item.id}.jpg');
    }
    await _mediaCol(uid).doc(item.id).delete();
  }

  static Future<void> _deleteObject(String path) async {
    try {
      await _storage.ref(path).delete();
    } catch (_) {
      // Object may already be gone; the Firestore delete is what matters.
    }
  }

  static String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }
}
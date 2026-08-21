// lib/models/media_item.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum MediaType { photo, video }

enum MediaCategory { game, team, tournament, award, training }

/// A single portfolio media item stored at
/// users/{uid}/media/{id}. Photos in Phase 2; videos land in Phase 3
/// (durationSeconds stays null for photos).
class MediaItem {
  final String id;
  final MediaType type;
  final String url;
  final String thumbnailUrl;
  final MediaCategory category;
  final String caption;
  final DateTime createdAt;
  final int sizeBytes;
  final int? durationSeconds;

  const MediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.thumbnailUrl,
    required this.category,
    required this.caption,
    required this.createdAt,
    required this.sizeBytes,
    this.durationSeconds,
  });

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'url': url,
        'thumbnailUrl': thumbnailUrl,
        'category': category.name,
        'caption': caption,
        'createdAt': Timestamp.fromDate(createdAt),
        'sizeBytes': sizeBytes,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
      };

  factory MediaItem.fromMap(String id, Map<String, dynamic> map) {
    final url = map['url'] as String? ?? '';
    final thumb = map['thumbnailUrl'] as String?;
    return MediaItem(
      id: id,
      type: (map['type'] == 'video') ? MediaType.video : MediaType.photo,
      url: url,
      thumbnailUrl: (thumb != null && thumb.isNotEmpty) ? thumb : url,
      category: MediaCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => MediaCategory.game,
      ),
      caption: map['caption'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case MediaCategory.game:
        return 'Game';
      case MediaCategory.team:
        return 'Team';
      case MediaCategory.tournament:
        return 'Tournament';
      case MediaCategory.award:
        return 'Award';
      case MediaCategory.training:
        return 'Training';
    }
  }
}
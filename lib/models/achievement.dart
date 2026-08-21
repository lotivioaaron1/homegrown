// lib/models/achievement.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single achievement/award entry in an athlete's portfolio, stored
/// at users/{uid}/achievements/{achievementId}.
class Achievement {
  final String id;
  final String title;
  final String description;
  final DateTime date;
  /// Lucide icon key (e.g. 'trophy', 'medal', 'star', 'award') — resolved
  /// to a LucideIcons constant in the widget layer, not stored as IconData
  /// since this value round-trips through Firestore.
  final String icon;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    this.icon = 'trophy',
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'icon': icon,
    };
  }

  factory Achievement.fromMap(String id, Map<String, dynamic> map) {
    final dateRaw = map['date'];
    return Achievement(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      date: dateRaw is Timestamp ? dateRaw.toDate() : DateTime.now(),
      icon: map['icon'] as String? ?? 'trophy',
    );
  }
}

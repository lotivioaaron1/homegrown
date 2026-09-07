// lib/models/report.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// A complaint raised by one user about another user or an event, stored at
/// `reports/{reportId}` and read only by the super-admin.
///
/// [targetType] is kept generic rather than splitting user reports and event
/// reports into two collections: the admin queue wants them interleaved by
/// recency, and adding a third target later should not mean a third query.
///
/// [targetLabel] is denormalised on purpose. The queue renders dozens of rows,
/// and resolving each target's name at render time would mean a second read
/// per row — and would show nothing at all once the target is deleted, which
/// is precisely when the admin most needs to know what was reported.
class Report {
  final String id;
  final String reporterUid;
  final String reporterName;

  /// 'user' | 'event'
  final String targetType;
  final String targetId;
  final String targetLabel;

  /// One of [Report.reasons].
  final String reason;
  final String details;

  /// 'open' | 'resolved' | 'dismissed'
  final String status;

  final DateTime? createdAt;
  final String resolvedBy;
  final DateTime? resolvedAt;

  const Report({
    required this.id,
    required this.reporterUid,
    required this.reporterName,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.reason,
    required this.details,
    required this.status,
    this.createdAt,
    this.resolvedBy = '',
    this.resolvedAt,
  });

  /// The fixed set a reporter picks from. A closed list keeps the queue
  /// scannable and keeps free text optional rather than load-bearing.
  static const List<String> reasons = [
    'Fake or impersonated account',
    'Harassment or abusive behaviour',
    'Inappropriate content',
    'Spam or scam',
    'Incorrect or misleading information',
    'Something else',
  ];

  static const String statusOpen = 'open';
  static const String statusResolved = 'resolved';
  static const String statusDismissed = 'dismissed';

  static const String targetUser = 'user';
  static const String targetEvent = 'event';

  bool get isOpen => status == statusOpen;

  Map<String, dynamic> toMap() {
    return {
      'reporterUid': reporterUid,
      'reporterName': reporterName,
      'targetType': targetType,
      'targetId': targetId,
      'targetLabel': targetLabel,
      'reason': reason,
      'details': details,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'resolvedBy': resolvedBy,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  factory Report.fromMap(String id, Map<String, dynamic> map) {
    return Report(
      id: id,
      reporterUid: map['reporterUid'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      targetType: map['targetType'] as String? ?? targetUser,
      targetId: map['targetId'] as String? ?? '',
      targetLabel: map['targetLabel'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      details: map['details'] as String? ?? '',
      status: map['status'] as String? ?? statusOpen,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      resolvedBy: map['resolvedBy'] as String? ?? '',
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
    );
  }
}

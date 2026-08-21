// lib/utils/firestore_helpers.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore has no schema enforcement, so a field expected to be a
/// [Timestamp] can end up as something else (e.g. a string typed in by
/// hand through the console). Use this instead of `as Timestamp?` so a
/// malformed value is treated as missing rather than crashing the widget
/// that reads it.
Timestamp? asTimestamp(dynamic value) => value is Timestamp ? value : null;

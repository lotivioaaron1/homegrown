// lib/utils/profile_format.dart

// How optional profile numbers are shown.
//
// Height and weight are optional at sign-up, so plenty of athletes never set
// them. The profile card coaches see used to glue the unit straight onto
// whatever was stored, which printed a bare "cm" / "kg" for an empty string
// and "—cm" for a missing field — both of which read as a broken screen.

/// [value] with [unit] appended, or "—" when there is nothing to show.
///
/// Takes `Object?` because the fields arrive straight off a Firestore map:
/// registration stores them as strings, but an int from an older document
/// must print the same way.
String formatMeasure(Object? value, String unit) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '—';
  return '$text$unit';
}

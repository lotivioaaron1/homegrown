// lib/widgets/player_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// One player's face: their profile photo when they have one, their initials
/// on the brand gradient when they don't.
///
/// An event's `players[]` entry stores only `uid`, `fullName`, `position` and
/// `team` — no photo — so the URL can never come off the event document.
/// Callers hydrate the live `users/{uid}` docs with [MemberProfilesBuilder] and
/// pass the resolved URL in; [name] is still required because it supplies the
/// initials, which is what renders on the first frame, for a player with no
/// photo, and when the image fails to load.
///
/// This exists as a public widget because the equivalent avatar in
/// [TeamRosterGrid] is private and keyed to `MemberIdentity`, and because the
/// event and stats screens had four hand-rolled copies of the same container
/// between them, none of which drew an image.
class PlayerAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;

  /// Corner radius; null gives a circle. The event rosters use circles, the
  /// create-event and Add Stats lists use rounded squares — each call site
  /// keeps the shape it already had rather than being normalised to one look.
  final double? radius;

  /// Defaults to a size-proportional value; passed explicitly where a call
  /// site's existing text size shouldn't shift by a fraction of a pixel.
  final double? fontSize;

  /// Overrides the brand gradient. Add Stats tints a player green once their
  /// stats are in.
  final List<Color>? gradient;

  const PlayerAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 36,
    this.radius,
    this.fontSize,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final corner = BorderRadius.circular(radius ?? size / 2);
    final fallback = Center(
      child: Text(
        name
            .trim()
            .split(' ')
            .where((s) => s.isNotEmpty)
            .take(2)
            .map((s) => s[0])
            .join()
            .toUpperCase(),
        style: TextStyle(
            color: AppTheme.buttonFg,
            fontSize: fontSize ?? size * 0.34,
            fontWeight: FontWeight.w800),
      ),
    );
    final url = photoUrl;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient ?? const [AppTheme.accent, AppTheme.accent2]),
        borderRadius: corner,
      ),
      child: ClipRRect(
        borderRadius: corner,
        child: (url != null && url.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: size,
                height: size,
                memCacheWidth: (size * 2.7).round(),
                // Both the placeholder and the error case fall back to the
                // initials rather than a spinner or a broken-image glyph: the
                // row should never be visually empty or look failed.
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              )
            : fallback,
      ),
    );
  }
}

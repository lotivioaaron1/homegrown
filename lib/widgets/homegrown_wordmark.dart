// lib/widgets/homegrown_wordmark.dart
import 'package:flutter/material.dart';

/// The Homegrown wordmark.
///
/// Ships as two files because the lockup is two-tone: "Home" is near-black and
/// "Grown" is gold. The black half vanishes on a dark background, so each
/// variant is drawn for the surface it sits on rather than recoloured at
/// runtime — which a flat PNG cannot do anyway.
///
/// The artwork is roughly 11:1, so it is sized by width and left to derive its
/// own height. Constraining the height instead would make it overflow narrow
/// phones.
class HomegrownWordmark extends StatelessWidget {
  /// Target width in logical pixels. Height follows the artwork's aspect.
  final double width;

  /// Forces the light-ink variant regardless of the app theme.
  ///
  /// The splash is a fixed dark scene in both themes, so it always needs the
  /// on-dark artwork; leaving it theme-aware there would put black letters on
  /// a black photograph whenever the user is in light mode.
  final bool onDark;

  const HomegrownWordmark({
    super.key,
    required this.width,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final useDarkVariant =
        onDark || Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      useDarkVariant
          ? 'assets/images/wordmark_on_dark.png'
          : 'assets/images/wordmark_on_light.png',
      width: width,
      fit: BoxFit.contain,
      // Read aloud as the brand name rather than announced as an image.
      semanticLabel: 'Homegrown',
    );
  }
}

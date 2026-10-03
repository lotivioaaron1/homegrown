// lib/constants/app_links.dart
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Public web pages the app links out to.
///
/// All three are served by GitHub Pages from the `docs/` folder of this
/// repository (Settings → Pages → Deploy from a branch → main → /docs), so a
/// change to one of those pages is live only once it reaches main. Google Play
/// requires the privacy policy to be reachable from inside the app as well as
/// from the store listing, and requires the deletion page to work for people
/// who have already uninstalled.
///
/// If the repository is ever renamed or moved, these are the only strings
/// that need updating — and the Play Console listing needs the same change.
class AppLinks {
  static const String privacyPolicy =
      'https://lotivioaaron1.github.io/homegrown/privacy-policy.html';

  /// The rules for using the app — conduct, content, moderation, and that
  /// games are played at your own risk. Agreed to at registration alongside
  /// the privacy policy.
  static const String terms =
      'https://lotivioaaron1.github.io/homegrown/terms.html';

  static const String deleteAccountRequest =
      'https://lotivioaaron1.github.io/homegrown/delete-account.html';

  /// Opens [url] in the device browser. Returns false if no browser could
  /// handle it, so callers can tell the user instead of failing silently.
  ///
  /// Uses [LaunchMode.externalApplication] rather than an in-app webview: a
  /// privacy policy shown in the app's own chrome is easy to mistake for part
  /// of the app, and the address bar is what lets someone verify where the
  /// document actually came from.
  ///
  /// Note this needs the `<queries>` element in AndroidManifest.xml. Without
  /// it, Android 11+ hides other apps from package visibility and this returns
  /// false on every device even though a browser is installed.
  static Future<bool> open(String url) async {
    try {
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('AppLinks: could not open $url ($e)');
      return false;
    }
  }
}

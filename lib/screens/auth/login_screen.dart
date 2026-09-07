// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/auth_routing.dart';
import '../../widgets/auth_hero.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/homegrown_wordmark.dart';

/// Hero photograph across the top, form on a rounded sheet lifted over it.
///
/// The sheet lives inside the scroll view rather than beside it, which is what
/// makes the keyboard behave: the form slides up over the photograph instead
/// of fighting it for room. The photograph itself is pinned behind, so it does
/// not jump around while that happens.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _auth = Get.find<AuthController>();

  final _formKey            = GlobalKey<FormState>();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  /// Why the last attempt failed, or empty.
  ///
  /// Copied out of AuthController.errorMessage rather than observed through
  /// it. AuthController is a global singleton from main.dart's initialBinding,
  /// so its errorMessage outlives this screen twice over: a stale failure would
  /// still be on the banner the next time /login opened, and clearing it from
  /// initState assigned to an Rx during the build phase, which marked a live
  /// Obx dirty mid-build and put up a red screen. Local state has neither
  /// problem — it is created and destroyed with the screen.
  String _error = '';

  static const _kRadius       = 16.0;
  static const _kSheetRadius  = 28.0;
  static const _kErrorRed     = Color(0xFFFF5C5C);
  static const _kMaxFormWidth = 440.0; // caps width on tablets/large screens

  /// Already shipped, already used full-bleed in onboarding. Reusing it keeps
  /// the auth flow photographic like the rest of the app rather than importing
  /// an illustration style nothing else here shares.
  static const _kHeroAsset = 'assets/images/onboard_basketball.jpg';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = '');
    await _auth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    // On success the controller has already routed away, so this screen is
    // gone and errorMessage is empty either way.
    if (!mounted) return;
    setState(() => _error = _auth.errorMessage.value);
  }

  void _onForgotPassword() => Get.toNamed('/forgot-password');

  void _onSignUp() => Get.offNamed('/register');

  Future<void> _onGoogleSignIn() async {
    setState(() => _error = '');
    final role = await _auth.signInWithGoogle();
    if (!mounted) return;
    if (role == null) {
      // New Google user — no role yet → go to profile setup
      final user = _auth.firebaseUser.value;
      if (user != null) {
        Get.offAllNamed('/google-profile-setup');
        return;
      }
      // Still signed out, so the attempt failed or the picker was dismissed.
      // errorMessage is empty for a dismissal, which collapses the banner —
      // backing out of the picker is not a failure worth reporting.
      setState(() => _error = _auth.errorMessage.value);
      return;
    }
    // Existing user with a role. Routed through the same landingRoute as
    // splash and email sign-in so the admin branch cannot drift between the
    // three entry points. A Google account holds no password credential, so
    // the verification gate correctly does not apply to it.
    final user = _auth.firebaseUser.value;
    Get.offAllNamed(landingRoute(
      role: role,
      emailVerified: user?.emailVerified ?? true,
      hasPasswordProvider: hasPasswordProvider(
          user?.providerData.map((p) => p.providerId) ?? const []),
      suspended: _auth.lastSignInSuspended,
    ));
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Shorter devices give the photograph less room so the form is not pushed
    // into a scroll fight with the keyboard.
    // Sized so the sign-up link still clears the fold on a normal phone.
    // At 0.38 the photograph looked better in isolation but pushed the only
    // route to registration off the bottom of the screen, which is a poor
    // trade on the screen a new user lands on by mistake.
    final heroHeight = (size.height * (size.height < 700 ? 0.28 : 0.34))
        .clamp(170.0, 310.0);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          AuthHero(
            asset: _kHeroAsset,
            height: heroHeight,
            // The subject sits in the upper two-thirds of a tall portrait
            // frame, so a centred cover crop lands on the shorts and cuts the
            // head off. Biasing upward keeps the face and the ball — the part
            // that carries the photograph — inside a short, wide window. Tuned
            // to this frame; it does not transfer to another photograph.
            alignment: const Alignment(0, -0.62),
          ),
          LayoutBuilder(
            builder: (context, viewport) {
              // The sheet starts one corner-radius above the photograph's
              // bottom edge, so it reads as lifted over it rather than butted
              // against it.
              final spacer = heroHeight - _kSheetRadius;

              return SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: spacer),
                    ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: viewport.maxHeight - spacer),
                      child: _sheet(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sheet() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_kSheetRadius),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Carries the splash's identity through to the first screen
                // you actually use, so the two do not read as unrelated.
                //
                // On the sheet rather than over the photograph: any crop that
                // puts the athlete's head near the top — which a good crop
                // does — collides with a centred wordmark, and swapping the
                // hero to the volleyball or badminton frame moves the
                // collision somewhere new. Here it is legible whatever the
                // picture does, and theme-aware because the sheet is.
                const Center(child: HomegrownWordmark(width: 118)),

                const SizedBox(height: 18),

                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to your Homegrown account',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.sub, fontSize: 13.5),
                ),

                const SizedBox(height: 28),

                // ── Email ─────────────────────
                TextFormField(
                  controller:      _emailController,
                  keyboardType:    TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints:   const [AutofillHints.email],
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco(
                    label:    'Email address',
                    iconData: LucideIcons.mail,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!GetUtils.isEmail(v.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Password ──────────────────
                TextFormField(
                  controller:       _passwordController,
                  obscureText:      _obscurePassword,
                  textInputAction:  TextInputAction.done,
                  onFieldSubmitted: (_) => _onSignIn(),
                  autofillHints:    const [AutofillHints.password],
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: _inputDeco(
                    label:    'Password',
                    iconData: LucideIcons.lock,
                    suffix: IconButton(
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? LucideIcons.eyeOff
                            : LucideIcons.eye,
                        color: AppTheme.muted,
                        size: 19,
                      ),
                      // An icon-only control needs a name, and the name has to
                      // say what tapping it does, not what it currently shows.
                      tooltip: _obscurePassword
                          ? 'Show password'
                          : 'Hide password',
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Password is required';
                    }
                    if (v.length < 8) {
                      return 'At least 8 characters required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // ── Forgot Password ───────────
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _onForgotPassword,
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      // Pads a 13px label out to a 44px-tall tap target.
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color:      AppTheme.accent,
                          fontSize:   13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Failure message ───────────
                // Inline rather than in a snackbar. The message this most
                // often carries — that the account may be a Google one — is
                // two clauses long and points at a button further down the
                // sheet, and a snackbar takes it away after three seconds,
                // usually before the user has finished reading it.
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ErrorBanner(message: _error),
                  ),

                const SizedBox(height: 14),

                // ── Sign In button ────────────
                Obx(() => GradientButton(
                      onPressed: _auth.isLoading.value ? null : _onSignIn,
                      borderRadius: _kRadius,
                      child: _auth.isLoading.value
                          ? const SizedBox(
                              width:  22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.buttonFg,
                              ),
                            )
                          : const Text('Sign In'),
                    )),

                const SizedBox(height: 20),

                // ── OR divider ────────────────
                Row(children: [
                  Expanded(child: Divider(color: AppTheme.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('OR', style: TextStyle(
                        color: AppTheme.muted, fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2))),
                  Expanded(child: Divider(color: AppTheme.border)),
                ]),

                const SizedBox(height: 20),

                // ── Google Sign-In ────────────
                Obx(() => SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: _auth.isGoogleLoading.value
                        ? null : _onGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(_kRadius)),
                    ),
                    child: _auth.isGoogleLoading.value
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.2, color: AppTheme.accent))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) => Text('G',
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 10),
                              Text('Continue with Google',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                )),

                const SizedBox(height: 22),

                // ── Sign Up link ──────────────
                GestureDetector(
                  onTap: _onSignUp,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text:  "Don't have an account?  ",
                        style: TextStyle(color: AppTheme.sub, fontSize: 14),
                        children: const [
                          TextSpan(
                            text: 'Sign Up',
                            style: TextStyle(
                              color:      AppTheme.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Input decoration ──────────────────────────

  /// Filled and borderless until focused, which is where the soft look comes
  /// from — the reference's fields have no resting outline at all.
  ///
  /// [label] is a real floating label rather than a hint. A placeholder is the
  /// only thing naming the field, so the moment someone types, the field stops
  /// saying what it is; the label survives that by floating instead.
  InputDecoration _inputDeco({
    required String   label,
    required IconData iconData,
    Widget?           suffix,
  }) {
    final radius = BorderRadius.circular(_kRadius);

    return InputDecoration(
      labelText:  label,
      labelStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
          color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600),
      prefixIcon: Icon(iconData, color: AppTheme.muted, size: 19),
      suffixIcon: suffix,
      filled:     true,
      fillColor:  AppTheme.inputFill,
      contentPadding: const EdgeInsets.symmetric(
          vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide.none),
      // No resting outline. The fill alone carries the field, which is what
      // keeps the form quiet.
      enabledBorder: OutlineInputBorder(
          borderRadius: radius, borderSide: BorderSide.none),
      // Focus is the one state that must stay obvious, so the gold ring stays.
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: _kErrorRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: _kErrorRed, width: 1.5)),
      errorStyle: const TextStyle(color: _kErrorRed, fontSize: 12),
    );
  }
}

// ─────────────────────────────────────────────
// Failure banner
// ─────────────────────────────────────────────

/// The reason a sign-in attempt failed, held on the sheet until the next one.
///
/// Private because it has a single caller. Colours come from the semantic
/// getters rather than the file-local `_kErrorRed`, which is a fixed value
/// tuned for a hairline field border and is too hot to sit behind a block of
/// body text in light mode.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorText.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, color: AppTheme.errorText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              // Announced on its own, because it appears without focus moving
              // and a screen reader would otherwise never reach it.
              semanticsLabel: message,
              style: TextStyle(
                color: AppTheme.errorText,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

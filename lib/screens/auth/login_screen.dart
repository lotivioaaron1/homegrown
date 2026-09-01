// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/homegrown_wordmark.dart';

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

  static const _kRadius     = 14.0;
  static const _kErrorRed   = Color(0xFFFF5C5C);
  static const _kMaxFormWidth = 440.0; // caps width on tablets/large screens

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────

  Future<void> _onSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    await _auth.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
  }

  void _onForgotPassword() => Get.toNamed('/forgot-password');

  void _onSignUp() => Get.offNamed('/register');

  Future<void> _onGoogleSignIn() async {
    final role = await _auth.signInWithGoogle();
    if (role == null) {
      // New Google user — no role yet → go to profile setup
      final user = _auth.firebaseUser.value;
      if (user != null) {
        Get.offAllNamed('/google-profile-setup');
      }
      return;
    }
    // Existing user with role → go straight home, unless they're the
    // super-admin (see auth_controller.dart's signInWithEmail for why this
    // check has to live at every sign-in entry point, not just splash).
    Get.offAllNamed(role == 'admin' ? '/admin' : '/home');
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    // Scale horizontal padding with screen width instead of a flat number,
    // so the form breathes on small phones and doesn't hug the edges on
    // wider ones. Clamped so it never gets too tight or too loose.
    final horizontalPadding = (size.width * 0.07).clamp(20.0, 32.0);

    // Shorter devices (e.g. SE-class phones) get tighter top spacing so
    // the form isn't pushed into a scroll fight with the keyboard.
    final isCompactHeight = size.height < 700;
    final topSpacing = isCompactHeight ? 48.0 : 76.0;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ConstrainedBox(
                // Guarantees the content column is at least one full
                // viewport tall, so the Spacer below has real room to
                // push the sign-up link toward the bottom. On short
                // content this pins it low; on tall content (small
                // phones, big text) it just scrolls normally.
                constraints: BoxConstraints(minHeight: viewport.maxHeight),
                child: IntrinsicHeight(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: _kMaxFormWidth),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(height: topSpacing),

                            // Carries the splash's wordmark through to the
                            // first screen you actually use. Without it the
                            // app goes from a full identity moment straight
                            // to bare form fields, and the two read as
                            // unrelated screens.
                            // Theme-aware here, unlike the splash: this screen
                            // follows the app theme, so the ink has to match
                            // whichever background it lands on.
                            HomegrownWordmark(
                                width: isCompactHeight ? 132 : 152),

                            SizedBox(height: isCompactHeight ? 18 : 24),

                            // ── Heading ───────────────────
                            Text(
                      'Welcome Back',
                      style: TextStyle(
                        // ✅ Adapts to light/dark
                        color:         AppTheme.textPrimary,
                        fontSize:      26,
                        fontWeight:    FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Sign in to your Homegrown account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:    AppTheme.sub,
                        fontSize: 14,
                      ),
                    ),

                    SizedBox(height: isCompactHeight ? 28 : 40),

                    // ── Email ─────────────────────
                    TextFormField(
                      controller:      _emailController,
                      keyboardType:    TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      // ✅ Adapts to light/dark
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco(
                        hint:     'Email address',
                        iconData: LucideIcons.mail,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Email is required';
                        if (!GetUtils.isEmail(v.trim()))
                          return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── Password ──────────────────
                    TextFormField(
                      controller:      _passwordController,
                      obscureText:     _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _onSignIn(),
                      // ✅ Adapts to light/dark
                      style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14),
                      decoration: _inputDeco(
                        hint:     'Password',
                        iconData: LucideIcons.lock,
                        suffix: GestureDetector(
                          onTap: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword
                                ? LucideIcons.eyeOff
                                : LucideIcons.eye,
                            color: AppTheme.muted,
                            size:  19,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty)
                          return 'Password is required';
                        if (v.length < 8)
                          return 'At least 8 characters required';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Forgot Password ───────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: _onForgotPassword,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color:      AppTheme.accent,
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: isCompactHeight ? 24 : 32),

                    // ── Sign In button ────────────
                    Obx(() => SizedBox(
                      width:  double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed:
                            _auth.isLoading.value ? null : _onSignIn,
                        child: _auth.isLoading.value
                            ? const SizedBox(
                                width:  22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  // Always dark — on gold button
                                  color: AppTheme.buttonFg,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
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
                      width: double.infinity, height: 54,
                      child: OutlinedButton(
                        onPressed: _auth.isGoogleLoading.value
                            ? null : _onGoogleSignIn,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_kRadius)),
                        ),
                        child: _auth.isGoogleLoading.value
                            ? SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.2, color: AppTheme.accent))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Lucide has no Google brand mark (it's a
                                  // generic icon set), so we keep a simple
                                  // styled "G" glyph instead of a mismatched
                                  // generic icon.
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

                    // Flexible gap: pushes the sign-up link down toward
                    // the bottom of the screen, with a sensible minimum
                    // so it never crowds the button above on tall content.
                    const Spacer(),
                    SizedBox(height: isCompactHeight ? 32 : 40),

                    // ── Sign Up link ──────────────
                    GestureDetector(
                      onTap: _onSignUp,
                      child: RichText(
                        text: TextSpan(
                          text:  "Don't have an account?  ",
                          style: TextStyle(
                              color: AppTheme.sub, fontSize: 14),
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

                    SizedBox(height: isCompactHeight ? 32 : 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Input decoration ──────────────────────────

  InputDecoration _inputDeco({
    required String   hint,
    required IconData iconData,
    Widget?           suffix,
  }) {
    return InputDecoration(
      hintText:   hint,
      hintStyle:  TextStyle(color: AppTheme.muted, fontSize: 14),
      prefixIcon: Icon(iconData, color: AppTheme.muted, size: 19),
      suffixIcon: suffix,
      filled:     true,
      fillColor:  AppTheme.card,
      contentPadding: const EdgeInsets.symmetric(
          vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide:   BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide:
              BorderSide(color: AppTheme.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(
              color: AppTheme.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(
              color: _kErrorRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(
              color: _kErrorRed, width: 1.5)),
      errorStyle: const TextStyle(
          color: _kErrorRed, fontSize: 12),
    );
  }
}

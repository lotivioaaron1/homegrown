// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';

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

  static const _kRadius   = 14.0;
  static const _kErrorRed = Color(0xFFFF5C5C);

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
    // Existing user with role → go straight home
    Get.offAllNamed('/home');
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 52),

                // ── Logo ──────────────────────
                Container(
                  width:  68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin:  Alignment.topLeft,
                      end:    Alignment.bottomRight,
                      colors: [AppTheme.accent, AppTheme.accent2],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:        AppTheme.accent.withValues(alpha: 0.3),
                        blurRadius:   24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'HG',
                      style: TextStyle(
                        // Always dark — sitting on gold background
                        color:      AppTheme.buttonFg,
                        fontSize:   24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

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
                  style: TextStyle(
                    color:    AppTheme.sub,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 40),

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
                    iconData: Icons.mail_outline_rounded,
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
                    iconData: Icons.lock_outline_rounded,
                    suffix: GestureDetector(
                      onTap: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.muted,
                        size:  20,
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

                const SizedBox(height: 32),

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

                const SizedBox(height: 24),

                // ── OR divider ────────────────
                Row(children: [
                  Expanded(child: Divider(color: AppTheme.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(
                        color: AppTheme.muted, fontSize: 12,
                        fontWeight: FontWeight.w600))),
                  Expanded(child: Divider(color: AppTheme.border)),
                ]),

                const SizedBox(height: 24),

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
                              Icon(Icons.g_mobiledata_rounded,
                                  color: AppTheme.textPrimary, size: 26),
                              const SizedBox(width: 6),
                              Text('Continue with Google',
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            ],
                          ),
                  ),
                )),

                const SizedBox(height: 40),

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

                const SizedBox(height: 32),
              ],
            ),
          ),
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
      prefixIcon: Icon(iconData, color: AppTheme.muted, size: 20),
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
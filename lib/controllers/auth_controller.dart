// lib/controllers/auth_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/auth_service.dart';
import '../services/contact_service.dart';
import '../utils/auth_routing.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find();

  final AuthService       _authService = AuthService();
  final FirebaseFirestore _firestore   = FirebaseFirestore.instance;
  final GoogleSignIn      _googleSignIn = GoogleSignIn();

  // ── Reactive state ────────────────────────────

  final RxBool    isLoading    = false.obs;
  final RxBool    isGoogleLoading = false.obs;
  final RxString  errorMessage = ''.obs;
  final Rx<User?> firebaseUser = Rx<User?>(null);

  @override
  void onInit() {
    super.onInit();
    // Bind stream so firebaseUser stays up to date,
    // but do NOT auto-navigate — splash screen handles routing.
    firebaseUser.bindStream(
        FirebaseAuth.instance.authStateChanges());
  }

  // ── Sign In (Email) ────────────────────────────

  Future<void> signInWithEmail(String email, String password) async {
    try {
      isLoading.value    = true;
      errorMessage.value = '';

      final credential = await _authService.signInWithEmail(email, password);
      final user = credential.user!;

      // Sign-in still succeeds, but an unverified password account gets no
      // further than the verification screen. This is an in-app gate, not a
      // security boundary — a script holding the same credentials bypasses it
      // entirely. What actually protects contact details is that they no
      // longer live on the readable user doc (see ContactService and the
      // users/{uid}/private rule). See landingRoute for why admins and Google
      // accounts are treated differently.
      final doc = await _firestore.collection('users').doc(user.uid).get();
      Get.offAllNamed(landingRoute(
        role: doc.data()?['role'] as String? ?? '',
        emailVerified: user.emailVerified,
        hasPasswordProvider:
            hasPasswordProvider(user.providerData.map((p) => p.providerId)),
      ));

    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapFirebaseError(e.code);
      _showErrorSnackbar(errorMessage.value);
    } catch (_) {
      errorMessage.value = 'Something went wrong. Please try again.';
      _showErrorSnackbar(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Register (Email) ───────────────────────────

  Future<void> registerWithEmail({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      isLoading.value    = true;
      errorMessage.value = '';

      final credential =
          await _authService.registerWithEmail(email, password);
      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid':       uid,
        'firstName': firstName,
        'lastName':  lastName,
        'role':      role,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Email lives in users/{uid}/private, not on the profile doc every
      // signed-in account can read — see ContactService.
      await ContactService.write(uid: uid, email: email);

      // Send verification email right after account creation
      await credential.user?.sendEmailVerification();

    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapFirebaseError(e.code);
      _showErrorSnackbar(errorMessage.value);
    } catch (_) {
      errorMessage.value = 'Registration failed. Please try again.';
      _showErrorSnackbar(errorMessage.value);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Google Sign-In ──────────────────────────────
  // Returns the role string if account already exists with a role set,
  // otherwise returns null (caller should route to role-selection).

  Future<String?> signInWithGoogle() async {
    try {
      isGoogleLoading.value = true;
      errorMessage.value    = '';

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the picker
        isGoogleLoading.value = false;
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCred.user;
      if (user == null) return null;

      final docRef = _firestore.collection('users').doc(user.uid);
      final doc    = await docRef.get();

      if (!doc.exists) {
        // First-time Google sign-in — create a minimal profile.
        // 'role' stays unset until the user picks one in role-selection.
        final nameParts = (user.displayName ?? '').trim().split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName  = nameParts.length > 1
            ? nameParts.sublist(1).join(' ') : '';

        await docRef.set({
          'uid':             user.uid,
          'firstName':       firstName,
          'lastName':        lastName,
          'role':            '',
          // Every avatar in the app reads 'photoUrl' (home, profile,
          // leaderboard, scout, team). Don't invent a second field name here.
          'photoUrl':        user.photoURL ?? '',
          'authProvider':    'google',
          'createdAt':       FieldValue.serverTimestamp(),
        });
        await ContactService.write(uid: user.uid, email: user.email ?? '');
        return null; // No role yet → caller routes to role selection
      }

      // Self-heal accounts created before avatars were standardised on
      // 'photoUrl': their Google picture went into 'profileImageUrl', which
      // no screen ever read, so it silently never appeared. One write, on
      // the first sign-in after this shipped. Email-registered accounts have
      // nothing to migrate — their old field was always empty.
      final data = doc.data() ?? {};
      final legacyUrl = data['profileImageUrl'] as String? ?? '';
      if ((data['photoUrl'] as String? ?? '').isEmpty && legacyUrl.isNotEmpty) {
        await docRef.update({'photoUrl': legacyUrl});
      }

      final role = data['role'] as String? ?? '';
      return role.isEmpty ? null : role;

    } on FirebaseAuthException catch (e) {
      errorMessage.value = _mapFirebaseError(e.code);
      _showErrorSnackbar(errorMessage.value);
      return null;
    } catch (e, st) {
      // debugPrint is stripped in release builds; print() is not, and would
      // leak the raw exception and stack trace to logcat on user devices.
      debugPrint('GOOGLE SIGN-IN ERROR: $e');
      debugPrint('STACK TRACE: $st');
      // The overwhelmingly common cause here is a signing-certificate SHA-1
      // that isn't registered in Firebase, which surfaces as an opaque
      // PlatformException. Don't put that in front of the user.
      errorMessage.value =
          "Couldn't sign in with Google. Check your connection and try again.";
      _showErrorSnackbar(errorMessage.value);
      return null;
    } finally {
      isGoogleLoading.value = false;
    }
  }

  // ── Email verification helpers ─────────────────

  Future<bool> checkEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  }

  Future<void> resendVerificationEmail() async {
    await FirebaseAuth.instance.currentUser?.sendEmailVerification();
  }

  // ── Sign Out ──────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    try { await _googleSignIn.signOut(); } catch (_) {}
    Get.offAllNamed('/splash');
  }

  // ── Error mapping ─────────────────────────────

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar(
      'Sign In Failed',
      message,
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF2A1A1A),
      colorText:       const Color(0xFFFF5C5C),
      icon: const Icon(
        Icons.error_outline,
        color: Color(0xFFFF5C5C),
      ),
      margin:       const EdgeInsets.all(16),
      borderRadius: 12,
      duration:     const Duration(seconds: 3),
    );
  }
}
// lib/screens/auth/organizer_register_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/privacy_consent_text.dart';
import '../../widgets/barangay_picker_sheet.dart';
import '../../widgets/profile_photo_picker.dart';
import '../../widgets/fill_viewport_scroll.dart';
import '../../services/contact_service.dart';
import '../../services/notification_service.dart';
import '../../utils/auth_routing.dart';
import '../../utils/registration_rollback.dart';
import '../../services/storage_service.dart';
import '../../utils/error_messages.dart';

const _kRadius   = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);
const List<String> _kSports   = ['Basketball', 'Volleyball', 'Badminton'];
const List<String> _kOrgTypes = [
  'Barangay', 'School', 'Community', 'Private', 'Government'
];

class OrganizerRegisterScreen extends StatefulWidget {
  const OrganizerRegisterScreen({super.key});
  @override
  State<OrganizerRegisterScreen> createState() =>
      _OrganizerRegisterScreenState();
}

class _OrganizerRegisterScreenState
    extends State<OrganizerRegisterScreen> {
  int _step = 0; bool _showSuccess = false; bool _isLoading = false;
  final _step1Key = GlobalKey<FormState>();

  // Step 1
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  String _selectedBarangay = '';
  bool _obscurePw = true; bool _obscureConfirm = true;

  // Step 2
  final _organizationCtrl = TextEditingController();
  String _organizationType = '';
  final List<String> _sportsOrganized = [];

  // Step 3
  File? _profileImage;
  final _bioCtrl           = TextEditingController();
  final _certificationsCtrl = TextEditingController();
  // Optional — a photo an admin can weigh when reviewing this signup (a
  // barangay certificate, business permit, or a team photo). Never made
  // required: that risks abandoning legitimate signups who don't have
  // something ready, so the admin screen just flags its absence instead.
  File? _verificationDoc;

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl, _phoneCtrl,
      _passwordCtrl, _confirmCtrl, _organizationCtrl,
      _bioCtrl, _certificationsCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickVerificationDoc() async {
    // Wider than the avatar below on purpose — this one has to stay legible
    // enough for an admin to read a permit or certificate off it.
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked != null) setState(() => _verificationDoc = File(picked.path));
  }

  // ── Profile photo ─────────────────────────

  Future<void> _pickImage() async {
    // maxWidth matters: without it a modern phone camera shot uploads at
    // full resolution, which blows past the "max 5MB" the UI promises.
    // Matches edit_profile_screen.dart's avatar picker.
    final p = await ImagePicker().pickImage(
        source: ImageSource.gallery, maxWidth: 1000, imageQuality: 80);
    if (p != null && mounted) setState(() => _profileImage = File(p.path));
  }

  /// Uploads the avatar picked in step 3 and points the user's doc at it.
  /// Must run *after* account creation: storage.rules requires
  /// `request.auth.uid == uid`, which only holds once the new user is
  /// signed in.
  ///
  /// Deliberately swallows its own failures rather than letting them reach
  /// _onCreateAccount's catch. By this point the account already exists, so
  /// bouncing the user back to the form is a dead end — their retry would
  /// just fail with 'email-already-in-use'. A missing photo is recoverable
  /// from Edit Profile; a stranded account is not.
  Future<void> _uploadProfilePhoto(String uid) async {
    if (_profileImage == null) return;
    try {
      final url = await StorageService.uploadProfilePhoto(uid, _profileImage!);
      await FirebaseFirestore.instance
          .collection('users').doc(uid).update({'photoUrl': url});
    } catch (_) {
      _snack('Photo not uploaded',
          'Your account was created. You can add a photo from Edit Profile.');
    }
  }

  // ── Barangay picker ───────────────────────

  Future<void> _pickBarangay() async {
    final picked = await showBarangayPickerSheet(context,
        selected: _selectedBarangay);
    if (picked != null) setState(() => _selectedBarangay = picked);
  }

  // ── Navigation ────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      if (!_step1Key.currentState!.validate()) return;
      if (_selectedBarangay.isEmpty) {
        _snack('Barangay', 'Please select your barangay.'); return;
      }
    }
    if (_step == 1) {
      if (_organizationCtrl.text.trim().isEmpty) {
        _snack('Organization', 'Please enter your organization name.'); return;
      }
      if (_organizationType.isEmpty) {
        _snack('Type', 'Please select an organization type.'); return;
      }
      if (_sportsOrganized.isEmpty) {
        _snack('Sports', 'Please select at least one sport.'); return;
      }
    }
    setState(() => _step++);
  }

  void _prevStep() { if (_step > 0) setState(() => _step--); }

  Future<void> _onCreateAccount() async {
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      // See athlete_register_screen.dart — both writes are required, so a
      // failure has to take the Auth account with it rather than strand the
      // email address.
      await withRegistrationRollback(
        deleteAccount: () => cred.user!.delete(),
        writes: () async {
          await FirebaseFirestore.instance
              .collection('users').doc(cred.user!.uid).set({
            'uid':             cred.user!.uid,
            'firstName':       _firstNameCtrl.text.trim(),
            'lastName':        _lastNameCtrl.text.trim(),
            'fullName': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
            'role':            'organizer',
            // An organizer can't create/publish events until a super-admin
            // approves this — see firestore.rules and admin_review_screen.dart.
            'organizerStatus': 'pending',
            'barangay':        _selectedBarangay,
            'organization':    _organizationCtrl.text.trim(),
            'organizationType': _organizationType,
            'sportsOrganized': _sportsOrganized,
            'bio':             _bioCtrl.text.trim(),
            'certifications':  _certificationsCtrl.text.trim(),
            // Every avatar in the app reads 'photoUrl' (home, profile,
            // leaderboard, scout, team). Don't invent a second field name here.
            'photoUrl':        '',
            'createdAt':       FieldValue.serverTimestamp(),
          });
          // Email and phone are kept off the publicly-readable profile doc;
          // the super-admin reads them from users/{uid}/private when reviewing
          // this application — see ContactService and admin_review_screen.dart.
          await ContactService.write(
            uid: cred.user!.uid,
            email: _emailCtrl.text.trim(),
            phoneNumber: _phoneCtrl.text.trim(),
          );
        },
      );
      await cred.user?.sendEmailVerification();
      await _uploadProfilePhoto(cred.user!.uid);

      if (_verificationDoc != null) {
        await StorageService.uploadOrganizerVerificationDoc(
            cred.user!.uid, _verificationDoc!);
      }

      // Let the super-admin know someone's waiting, instead of relying on
      // them to remember to check /admin — see admin_review_screen.dart.
      final admins = await FirebaseFirestore.instance
          .collection('users').where('role', isEqualTo: 'admin').get();
      for (final admin in admins.docs) {
        await NotificationService.create(
          userId: admin.id,
          type: 'organizer_pending',
          title: 'New organizer awaiting approval',
          body: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()} '
              'registered as an organizer and needs review.',
          relatedId: cred.user!.uid,
        );
      }

      if (mounted) setState(() => _showSuccess = true);
    } on FirebaseAuthException catch (e) {
      _snack('Registration Failed', _mapError(e.code), isError: true);
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String t, String m, {bool isError = false}) {
    Get.snackbar(t, m,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
      colorText: isError ? _kErrorRed : AppTheme.textPrimary,
      margin: const EdgeInsets.all(16), borderRadius: 12,
      duration: const Duration(seconds: 3));
  }

  /// See athlete_register_screen.dart — one shared mapping across all three
  /// role registrations and sign-in.
  String _mapError(String code) =>
      authErrorMessage(code) ?? 'Registration failed. Please try again.';

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _SuccessView(firstName: _firstNameCtrl.text.trim());
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildProgressBar(),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          // Pin steps to the top — see coach_register_screen.dart for why
          // the default centred layout made short steps float mid-screen.
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current],
          ),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end:   Offset.zero).animate(anim),
            child: FadeTransition(opacity: anim, child: child)),
          child: KeyedSubtree(
              key: ValueKey<int>(_step), child: _buildStep()),
        )),
      ])),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: _step > 0 ? _prevStep : () => Get.back(),
        child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Icon(
            _step > 0
                ? Icons.arrow_back_ios_new_rounded
                : Icons.close_rounded,
            color: AppTheme.textPrimary,
            size: _step > 0 ? 16 : 18)),
      ),
      const Spacer(),
      Text('Step ${_step + 1} of 3', style: TextStyle(
          color: AppTheme.sub, fontSize: 13,
          fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: List.generate(3, (i) => Expanded(
      child: Container(height: 4,
        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
        decoration: BoxDecoration(
          color: i <= _step ? AppTheme.accent : AppTheme.border,
          borderRadius: BorderRadius.circular(2)),
      ),
    ))),
  );

  Widget _buildStep() {
    switch (_step) {
      case 0:  return _buildStep1();
      case 1:  return _buildStep2();
      default: return _buildStep3();
    }
  }

  // ── Step 1 — Personal Info ────────────────

  Widget _buildStep1() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(key: _step1Key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const _StepHeader(emoji: '📋', title: 'Organizer Sign Up',
              subtitle: 'Step 1 of 3 — Personal info'),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _Field(ctrl: _firstNameCtrl,
              hint: 'First Name',
              icon: Icons.person_outline_rounded,
              cap: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 10),
            Expanded(child: _Field(ctrl: _lastNameCtrl,
              hint: 'Last Name',
              icon: Icons.person_outline_rounded,
              cap: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
          ]),
          const SizedBox(height: 12),
          _Field(ctrl: _emailCtrl, hint: 'Email Address',
            icon: Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              if (v!.trim().isEmpty) return 'Email is required';
              if (!GetUtils.isEmail(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            }),
          const SizedBox(height: 12),
          _Field(ctrl: _phoneCtrl, hint: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            validator: (v) =>
                v!.trim().isEmpty ? 'Phone number is required' : null),
          const SizedBox(height: 4),
          Text('So an admin can reach you directly to verify your account.',
              style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          const SizedBox(height: 12),

          // ── Barangay picker ────────────────
          GestureDetector(
            onTap: _pickBarangay,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(
                  color: _selectedBarangay.isNotEmpty
                      ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
              child: Row(children: [
                Icon(Icons.location_on_outlined,
                  color: _selectedBarangay.isNotEmpty
                      ? AppTheme.accent : AppTheme.muted,
                  size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  _selectedBarangay.isNotEmpty
                      ? _selectedBarangay
                      : 'Select Barangay (Legazpi City)',
                  style: TextStyle(
                    color: _selectedBarangay.isNotEmpty
                        ? AppTheme.textPrimary : AppTheme.muted,
                    fontSize: 14))),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.muted, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          _Field(ctrl: _passwordCtrl, hint: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePw,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscurePw = !_obscurePw),
              child: Icon(
                _obscurePw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.muted, size: 20)),
            validator: (v) {
              if (v!.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters';
              if (!RegExp(r'[A-Z]').hasMatch(v)) {
                return 'Add at least one uppercase letter';
              }
              if (!RegExp(r'[0-9]').hasMatch(v)) {
                return 'Add at least one number';
              }
              return null;
            }),
          const SizedBox(height: 12),
          _Field(ctrl: _confirmCtrl, hint: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppTheme.muted, size: 20)),
            validator: (v) {
              if (v!.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) {
                return 'Passwords do not match';
              }
              return null;
            }),
          const SizedBox(height: 32),
          // See coach_register_screen.dart — replaces a fixed 262px gap that
          // only positioned the button correctly on one screen size.
          const Spacer(),
          _PrimaryButton(label: 'Next', onTap: _nextStep),
        ]),
      ),
    );
  }

  // ── Step 2 — Organization Details ─────────

  Widget _buildStep2() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const _StepHeader(emoji: '🏢', title: 'Organization',
            subtitle: 'Step 2 of 3 — Organization details'),
        const SizedBox(height: 24),
        const _SectionLabel(label: 'Organization Name'),
        const SizedBox(height: 8),
        _Field(ctrl: _organizationCtrl,
          hint: 'e.g. Legazpi City Sports Council',
          icon: Icons.business_outlined,
          cap: TextCapitalization.words),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Organization Type'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kOrgTypes.map((t) => _Chip(
            label: t, sel: _organizationType == t,
            onTap: () =>
                setState(() => _organizationType = t))).toList()),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Sports You Organize'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kSports.map((s) {
            final sel = _sportsOrganized.contains(s);
            return _Chip(label: s, sel: sel,
              onTap: () => setState(() =>
                  sel ? _sportsOrganized.remove(s)
                      : _sportsOrganized.add(s)));
          }).toList()),
        const SizedBox(height: 32),
        const Spacer(),
        _PrimaryButton(label: 'Next', onTap: _nextStep),
      ]),
    );
  }

  // ── Step 3 — Bio & Credentials ────────────

  Widget _buildStep3() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const _StepHeader(emoji: '🪪', title: 'Profile',
            subtitle: 'Step 3 of 3 — Photo, bio & credentials'),
        const SizedBox(height: 24),
        // Your public avatar — distinct from the verification document
        // further down, which is private and only an admin ever sees.
        ProfilePhotoPicker(image: _profileImage, onTap: _pickImage),
        const SizedBox(height: 24),
        const _SectionLabel(label: 'Bio (Optional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioCtrl, maxLines: 4, maxLength: 200,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: _textAreaDeco(
            'Tell athletes about your organization and mission...'),
        ),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Credentials / Certifications (Optional)'),
        const SizedBox(height: 8),
        _Field(ctrl: _certificationsCtrl,
          hint: 'e.g. PhilSports Accredited, LGU Recognized',
          icon: Icons.workspace_premium_outlined,
          cap: TextCapitalization.sentences),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Verification Photo (Optional)'),
        const SizedBox(height: 4),
        Text(
            'A barangay certificate, business permit, or a photo with '
            'your team — helps the admin verify you faster.',
            style: TextStyle(color: AppTheme.muted, fontSize: 11)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickVerificationDoc,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(
                    color: _verificationDoc != null
                        ? AppTheme.accent : AppTheme.border,
                    width: 1.5)),
            child: _verificationDoc != null
                ? Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_verificationDoc!,
                          width: 48, height: 48, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Photo attached',
                        style: TextStyle(
                            color: AppTheme.textPrimary, fontSize: 13,
                            fontWeight: FontWeight.w600))),
                    const Text('Change', style: TextStyle(
                        color: AppTheme.accent, fontSize: 12,
                        fontWeight: FontWeight.w700)),
                  ])
                : Row(children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: AppTheme.muted, size: 20),
                    const SizedBox(width: 12),
                    Text('Attach a photo',
                        style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                  ]),
          ),
        ),
        const SizedBox(height: 24),
        const PrivacyConsentText(),
        const SizedBox(height: 14),
        const Spacer(),
        _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : _PrimaryButton(
                label: 'Create Account',
                onTap: _onCreateAccount),
      ]),
    );
  }

  InputDecoration _textAreaDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
    filled: true, fillColor: AppTheme.card,
    counterStyle: TextStyle(color: AppTheme.sub),
    contentPadding: const EdgeInsets.all(14),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_kRadius),
        borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
  );
}

// ── Success view ──────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final String firstName;
  const _SuccessView({required this.firstName});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bg,
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center,
        children: [
        const Spacer(),
        Container(width: 110, height: 110,
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2)),
          child: const Center(child: Text('⏳',
              style: TextStyle(fontSize: 48)))),
        const SizedBox(height: 32),
        Text('Account Created!', textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 26,
              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text(
          "Hello $firstName! Your organizer account is being reviewed "
          "by our team — you'll be notified once you're approved and "
          "able to start creating events.",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppTheme.sub, fontSize: 15, height: 1.6)),
        const Spacer(),
        _PrimaryButton(label: 'Go to Home',
            // See athlete_register_screen.dart — a new account must clear the
            // verification gate before it can reach /home.
            onTap: () => Get.offAllNamed(kRouteVerifyEmail)),
        const SizedBox(height: 40),
      ]),
    )),
  );
}

// ── Shared widgets ────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final String emoji, title, subtitle;
  const _StepHeader({required this.emoji, required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 44, height: 44,
      decoration: BoxDecoration(color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
      child: Center(child: Text(emoji,
          style: const TextStyle(fontSize: 20)))),
    const SizedBox(width: 14),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: AppTheme.textPrimary,
          fontSize: 18, fontWeight: FontWeight.w800)),
      Text(subtitle, style: TextStyle(color: AppTheme.sub, fontSize: 12)),
    ]),
  ]);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
    style: TextStyle(color: AppTheme.textPrimary,
        fontSize: 13, fontWeight: FontWeight.w700));
}

class _Chip extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _Chip({required this.label, required this.sel,
      required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: sel ? AppTheme.accentSurface : AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sel ? AppTheme.accent : AppTheme.border,
          width: sel ? 2.0 : 1.5)),
      child: Text(label, style: TextStyle(
        color: sel ? AppTheme.accentText : AppTheme.muted,
        fontSize: 13,
        fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint; final IconData icon;
  final TextInputType? keyboard; final TextCapitalization cap;
  final bool obscure; final Widget? suffix;
  final String? Function(String?)? validator;

  const _Field({required this.ctrl, required this.hint,
    required this.icon, this.keyboard,
    this.cap = TextCapitalization.none,
    this.obscure = false, this.suffix, this.validator});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, obscureText: obscure,
    keyboardType: keyboard, textCapitalization: cap,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.muted, size: 20),
      suffixIcon: suffix, filled: true, fillColor: AppTheme.card,
      contentPadding: const EdgeInsets.symmetric(
          vertical: 15, horizontal: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kErrorRed, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: const BorderSide(color: _kErrorRed, width: 1.5)),
      errorStyle: const TextStyle(color: _kErrorRed, fontSize: 11)),
    validator: validator,
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
        onPressed: onTap, child: Text(label)));
}
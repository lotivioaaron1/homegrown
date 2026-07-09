// lib/screens/auth/athlete_register_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_theme.dart';
import '../../constants/legazpi_barangays.dart';

const _kRadius   = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);
const List<String> _kSports = ['Basketball', 'Volleyball', 'Badminton'];
const List<String> _kYears  = ['1-2 Yrs', '3-5 Yrs', '5+ Yrs'];

class AthleteRegisterScreen extends StatefulWidget {
  const AthleteRegisterScreen({super.key});
  @override
  State<AthleteRegisterScreen> createState() => _AthleteRegisterScreenState();
}

class _AthleteRegisterScreenState extends State<AthleteRegisterScreen> {
  int _step = 0; bool _showSuccess = false; bool _isLoading = false;
  final _step1Key = GlobalKey<FormState>();

  final _firstNameCtrl  = TextEditingController();
  final _lastNameCtrl   = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  String _selectedBarangay = '';
  bool _obscurePw = true; bool _obscureConfirm = true;

  final List<String> _selectedSports = [];
  final _positionCtrl = TextEditingController();
  String _yearsOfPlaying = '';
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  File? _profileImage;
  final _bioCtrl = TextEditingController();
  bool _isPublic = true; bool _openToRecruitment = true;

  @override
  void dispose() {
    for (final c in [_firstNameCtrl, _lastNameCtrl, _emailCtrl,
      _passwordCtrl, _confirmCtrl, _positionCtrl,
      _heightCtrl, _weightCtrl, _bioCtrl]) { c.dispose(); }
    super.dispose();
  }

  // ── Barangay picker ───────────────────────

  void _pickBarangay() {
    final search = TextEditingController();
    List<String> filtered = List.from(kLegazpiBarangays);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize:     0.92,
          builder: (_, ctrl) => Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text('Select Barangay', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: search,
                autofocus: true,
                style: TextStyle(color: AppTheme.textPrimary),
                onChanged: (q) => setModal(() {
                  filtered = kLegazpiBarangays
                      .where((b) => b.toLowerCase()
                          .contains(q.toLowerCase()))
                      .toList();
                }),
                decoration: InputDecoration(
                  hintText: 'Search barangay...',
                  hintStyle: TextStyle(color: AppTheme.muted),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppTheme.muted, size: 20),
                  filled: true, fillColor: AppTheme.bg,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppTheme.accent, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(
              controller: ctrl,
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final b = filtered[i];
                final sel = b == _selectedBarangay;
                return ListTile(
                  dense: true,
                  title: Text(b, style: TextStyle(
                    color: sel ? AppTheme.accentText : AppTheme.textPrimary,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14)),
                  trailing: sel
                      ? Icon(Icons.check_circle_rounded,
                          color: AppTheme.accent, size: 20)
                      : null,
                  onTap: () {
                    setState(() => _selectedBarangay = b);
                    Navigator.pop(context);
                  },
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  // ── Navigation ────────────────────────────

  void _nextStep() {
    if (_step == 0 && !_step1Key.currentState!.validate()) return;
    if (_step == 0 && _selectedBarangay.isEmpty) {
      _snack('Barangay', 'Please select your barangay.');
      return;
    }
    if (_step == 1) {
      if (_selectedSports.isEmpty) {
        _snack('Select Sport', 'Please select at least one sport.'); return;
      }
      if (_yearsOfPlaying.isEmpty) {
        _snack('Years', 'Please select your years of playing.'); return;
      }
    }
    setState(() => _step++);
  }

  void _prevStep() { if (_step > 0) setState(() => _step--); }

  Future<void> _pickImage() async {
    final p = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (p != null && mounted) setState(() => _profileImage = File(p.path));
  }

  Future<void> _onCreateAccount() async {
    setState(() => _isLoading = true);
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );
      await cred.user?.sendEmailVerification();
      await FirebaseFirestore.instance
          .collection('users').doc(cred.user!.uid).set({
        'uid':               cred.user!.uid,
        'firstName':         _firstNameCtrl.text.trim(),
        'lastName':          _lastNameCtrl.text.trim(),
        'fullName': '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        'email':             _emailCtrl.text.trim(),
        'role':              'athlete',
        'barangay':          _selectedBarangay,
        'primarySports':     _selectedSports,
        'position':          _positionCtrl.text.trim(),
        'yearsOfPlaying':    _yearsOfPlaying,
        'heightCm':          _heightCtrl.text.trim(),
        'weightKg':          _weightCtrl.text.trim(),
        'bio':               _bioCtrl.text.trim(),
        'isPublic':          _isPublic,
        'openToRecruitment': _openToRecruitment,
        'profileImageUrl':   '',
        'points':            0,
        'createdAt':         FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _showSuccess = true);
    } on FirebaseAuthException catch (e) {
      _snack('Registration Failed', _mapError(e.code), isError: true);
    } catch (e) {
      _snack('Error', e.toString(), isError: true);
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

  String _mapError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password':        return 'Password is too weak.';
      case 'invalid-email':        return 'Please enter a valid email.';
      default:                     return 'Registration failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) return _SuccessView(firstName: _firstNameCtrl.text.trim());
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildProgressBar(),
        Expanded(child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => SlideTransition(
            position: Tween<Offset>(
                begin: const Offset(0.08, 0), end: Offset.zero).animate(anim),
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
          child: Icon(_step > 0
              ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
              color: AppTheme.textPrimary, size: _step > 0 ? 16 : 18)),
      ),
      const Spacer(),
      Text('Step ${_step + 1} of 3', style: TextStyle(
          color: AppTheme.sub, fontSize: 13, fontWeight: FontWeight.w600)),
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

  // ── Step 1 ────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Form(key: _step1Key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StepHeader(emoji: '👤', title: 'Personal Info',
              subtitle: 'Step 1 of 3 — Your information'),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: _Field(ctrl: _firstNameCtrl, hint: 'First Name',
              icon: Icons.person_outline_rounded,
              cap: TextCapitalization.words,
              validator: (v) => v!.trim().isEmpty ? 'Required' : null)),
            const SizedBox(width: 10),
            Expanded(child: _Field(ctrl: _lastNameCtrl, hint: 'Last Name',
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
              if (!GetUtils.isEmail(v.trim())) return 'Enter a valid email';
              return null;
            }),
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
              onTap: () => setState(() => _obscurePw = !_obscurePw),
              child: Icon(_obscurePw
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  color: AppTheme.muted, size: 20)),
            validator: (v) {
              if (v!.isEmpty) return 'Password is required';
              if (v.length < 8) return 'At least 8 characters required';
              if (!RegExp(r'[A-Z]').hasMatch(v))
                return 'Add at least one uppercase letter';
              if (!RegExp(r'[0-9]').hasMatch(v))
                return 'Add at least one number';
              return null;
            }),
          const SizedBox(height: 12),
          _Field(ctrl: _confirmCtrl, hint: 'Confirm Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(_obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
                  color: AppTheme.muted, size: 20)),
            validator: (v) {
              if (v!.isEmpty) return 'Please confirm your password';
              if (v != _passwordCtrl.text) return 'Passwords do not match';
              return null;
            }),
          const SizedBox(height: 32),
          _PrimaryButton(label: 'Next', onTap: _nextStep),
        ]),
      ),
    );
  }

  // ── Step 2 ────────────────────────────────

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepHeader(emoji: '🏅', title: 'Your Sport',
            subtitle: 'Step 2 of 3 — Athletic details'),
        const SizedBox(height: 24),
        const _SectionLabel(label: 'Primary Sport'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kSports.map((s) {
            final sel = _selectedSports.contains(s);
            return _Chip(label: s, sel: sel,
              onTap: () => setState(() =>
                  sel ? _selectedSports.remove(s) : _selectedSports.add(s)));
          }).toList()),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Position / Role'),
        const SizedBox(height: 8),
        _Field(ctrl: _positionCtrl,
          hint: 'e.g. Point Guard, Setter, Singles',
          icon: Icons.sports_basketball_outlined,
          cap: TextCapitalization.words),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Years of Playing'),
        const SizedBox(height: 8),
        Wrap(spacing: 8,
          children: _kYears.map((y) => _Chip(
            label: y, sel: _yearsOfPlaying == y,
            onTap: () => setState(() => _yearsOfPlaying = y))).toList()),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel(label: 'Height (cm)'),
            const SizedBox(height: 8),
            _Field(ctrl: _heightCtrl, hint: 'e.g. 175',
              icon: Icons.height_rounded,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _SectionLabel(label: 'Weight (kg)'),
            const SizedBox(height: 8),
            _Field(ctrl: _weightCtrl, hint: 'e.g. 70',
              icon: Icons.monitor_weight_outlined,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
          ])),
        ]),
        const SizedBox(height: 32),
        _PrimaryButton(label: 'Next', onTap: _nextStep),
      ]),
    );
  }

  // ── Step 3 ────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _StepHeader(emoji: '🪪', title: 'Profile',
            subtitle: 'Step 3 of 3 — Photo & visibility'),
        const SizedBox(height: 24),
        Center(child: GestureDetector(
          onTap: _pickImage,
          child: Stack(children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppTheme.card, shape: BoxShape.circle,
                border: Border.all(color: AppTheme.border, width: 2),
                image: _profileImage != null
                    ? DecorationImage(image: FileImage(_profileImage!),
                        fit: BoxFit.cover) : null),
              child: _profileImage == null ? Column(
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined,
                    color: AppTheme.muted, size: 28),
                const SizedBox(height: 6),
                Text('Upload Photo', style: TextStyle(
                    color: AppTheme.muted, fontSize: 11)),
                Text('PNG or JPG, max 5MB', style: TextStyle(
                    color: AppTheme.muted.withValues(alpha: 0.6),
                    fontSize: 10)),
              ]) : null),
            Positioned(bottom: 4, right: 4,
              child: Container(width: 28, height: 28,
                decoration: BoxDecoration(color: AppTheme.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.bg, width: 2)),
                child: const Icon(Icons.edit_rounded,
                    color: AppTheme.buttonFg, size: 14))),
          ]),
        )),
        const SizedBox(height: 24),
        const _SectionLabel(label: 'Bio (Optional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioCtrl, maxLines: 3, maxLength: 150,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'e.g. Basketball player from Sagumbayan.',
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
                borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Profile Visibility'),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(label: '🌐  Public', sel: _isPublic,
              onTap: () => setState(() => _isPublic = true)),
          const SizedBox(width: 8),
          _Chip(label: '🔒  Private', sel: !_isPublic,
              onTap: () => setState(() => _isPublic = false)),
        ]),
        const SizedBox(height: 16),
        const _SectionLabel(label: 'Open to Recruitment'),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(label: '✅  Yes, recruit me', sel: _openToRecruitment,
              onTap: () => setState(() => _openToRecruitment = true)),
          const SizedBox(width: 8),
          _Chip(label: '❌  Not now', sel: !_openToRecruitment,
              onTap: () => setState(() => _openToRecruitment = false)),
        ]),
        const SizedBox(height: 32),
        _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : _PrimaryButton(label: 'Create Account',
                onTap: _onCreateAccount),
      ]),
    );
  }
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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Spacer(),
        Container(width: 110, height: 110,
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.accent, width: 2)),
          child: const Center(child: Text('🏆',
              style: TextStyle(fontSize: 48)))),
        const SizedBox(height: 32),
        Text("You're in, Athlete!", textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 28,
              fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Text('Welcome to Homegrown, $firstName!\nYour athletic journey starts now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.sub, fontSize: 15, height: 1.6)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('⭐', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('0 Points — Start playing to earn!',
              style: TextStyle(color: AppTheme.accentText,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          ])),
        const Spacer(),
        _PrimaryButton(label: 'Go to Home',
            onTap: () => Get.offAllNamed('/home')),
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
  const _Chip({required this.label, required this.sel, required this.onTap});
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
  final TextInputType? keyboard;
  final TextCapitalization cap;
  final bool obscure; final Widget? suffix;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? formatters;

  const _Field({required this.ctrl, required this.hint, required this.icon,
    this.keyboard, this.cap = TextCapitalization.none,
    this.obscure = false, this.suffix, this.validator, this.formatters});

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl, obscureText: obscure,
    keyboardType: keyboard, textCapitalization: cap,
    inputFormatters: formatters,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.muted, size: 20),
      suffixIcon: suffix, filled: true, fillColor: AppTheme.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kRadius),
          borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
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
    child: ElevatedButton(onPressed: onTap, child: Text(label)));
}
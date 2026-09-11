// lib/screens/auth/google_profile_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../constants/sport_icons.dart';
import '../../constants/sport_positions.dart';
import '../../services/contact_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/barangay_picker_sheet.dart';
import '../../widgets/position_picker_sheet.dart';
import '../../widgets/fill_viewport_scroll.dart';
import '../../utils/error_messages.dart';

const _kRadius   = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);
const List<String> _kSports    = ['Basketball', 'Volleyball', 'Badminton'];
// Same list as athlete_register_screen.dart and edit_profile_screen.dart.
const List<String> _kYears     = ['<1 Yr', '1-2 Yrs', '3-5 Yrs', '5+ Yrs'];
const List<String> _kLevels    = ['Barangay', 'City', 'Provincial', 'National'];
const List<String> _kOrgTypes  = ['Barangay', 'School', 'Community',
    'Private', 'Government'];

class GoogleProfileSetupScreen extends StatefulWidget {
  const GoogleProfileSetupScreen({super.key});

  @override
  State<GoogleProfileSetupScreen> createState() =>
      _GoogleProfileSetupScreenState();
}

class _GoogleProfileSetupScreenState
    extends State<GoogleProfileSetupScreen> {

  final String _uid   = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String _email = FirebaseAuth.instance.currentUser?.email ?? '';
  final String _displayName =
      FirebaseAuth.instance.currentUser?.displayName ?? '';

  int    _step      = 0;
  String _role      = '';
  bool   _isLoading = false;

  // ── Shared ────────────────────────────────
  String _selectedBarangay = '';

  // ── Athlete ───────────────────────────────
  final List<String> _selectedSports    = [];
  String _position                      = '';
  String _yearsOfPlaying                = '';
  final _heightCtrl                     = TextEditingController();
  final _weightCtrl                     = TextEditingController();
  final _bioCtrl                        = TextEditingController();
  final bool _isPublic           = true;
  bool _openToRecruitment  = true;

  // ── Coach ─────────────────────────────────
  final List<String> _coachSports = [];
  String _coachingLevel           = '';
  String _yearsOfExperience       = '';
  final _teamOrgCtrl              = TextEditingController();
  final _coachBioCtrl             = TextEditingController();
  final _certCtrl                 = TextEditingController();

  // ── Organizer ─────────────────────────────
  final _orgNameCtrl              = TextEditingController();
  String _orgType                 = '';
  final List<String> _orgSports   = [];
  final _orgBioCtrl               = TextEditingController();

  @override
  void dispose() {
    for (final c in [_heightCtrl, _weightCtrl,
      _bioCtrl, _teamOrgCtrl, _coachBioCtrl, _certCtrl,
      _orgNameCtrl, _orgBioCtrl]) { c.dispose(); }
    super.dispose();
  }

  // ── Derived name ──────────────────────────

  String get _firstName {
    if (_displayName.isEmpty) return '';
    return _displayName.split(' ').first;
  }

  String get _lastName {
    if (_displayName.isEmpty) return '';
    final parts = _displayName.split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  // ── Barangay picker ───────────────────────

  Future<void> _pickBarangay() async {
    final picked = await showBarangayPickerSheet(context,
        selected: _selectedBarangay);
    if (picked != null) setState(() => _selectedBarangay = picked);
  }

  // ── Position picker ───────────────────────

  Future<void> _pickPosition() async {
    final picked = await showPositionPickerSheet(context,
        sports: _selectedSports, selected: _position);
    if (picked != null) setState(() => _position = picked);
  }

  // ── Validation ────────────────────────────

  bool _canProceed() {
    if (_step == 0) return _role.isNotEmpty;
    if (_step == 1) {
      if (_selectedBarangay.isEmpty) return false;
      if (_role == 'athlete') {
        return _selectedSports.isNotEmpty &&
            _position.isNotEmpty &&
            _yearsOfPlaying.isNotEmpty;
      }
      if (_role == 'coach') {
        return _coachSports.isNotEmpty &&
            _coachingLevel.isNotEmpty &&
            _yearsOfExperience.isNotEmpty;
      }
      if (_role == 'organizer') {
        return _orgNameCtrl.text.trim().isNotEmpty &&
            _orgType.isNotEmpty &&
            _orgSports.isNotEmpty;
      }
    }
    return true;
  }

  void _nextStep() {
    if (!_canProceed()) {
      _snack('Required', 'Please fill in all required fields.');
      return;
    }
    if (_step < 1) {
      setState(() => _step++);
    } else {
      _saveProfile();
    }
  }

  // ── Save to Firestore ─────────────────────

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> data = {
        'uid':       _uid,
        'firstName': _firstName,
        'lastName':  _lastName,
        'fullName':  _displayName,
        'role':      _role,
        'barangay':  _selectedBarangay,
        'authProvider': 'google',
        // Every avatar in the app reads 'photoUrl' (home, profile,
        // leaderboard, scout, team). Don't invent a second field name here.
        'photoUrl':
            FirebaseAuth.instance.currentUser?.photoURL ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_role == 'athlete') {
        data.addAll({
          'primarySports':     _selectedSports,
          'position':          _position,
          'yearsOfPlaying':    _yearsOfPlaying,
          'heightCm':          _heightCtrl.text.trim(),
          'weightKg':          _weightCtrl.text.trim(),
          'bio':               _bioCtrl.text.trim(),
          'isPublic':          _isPublic,
          'openToRecruitment': _openToRecruitment,
          'points':            0,
        });
      } else if (_role == 'coach') {
        data.addAll({
          'primarySports':     _coachSports,
          'coachingLevel':     _coachingLevel,
          'yearsOfExperience': _yearsOfExperience,
          'teamOrganization':  _teamOrgCtrl.text.trim(),
          'coachingBio':       _coachBioCtrl.text.trim(),
          'certifications':    _certCtrl.text.trim(),
        });
      } else {
        data.addAll({
          'organization':      _orgNameCtrl.text.trim(),
          'organizationType':  _orgType,
          'sportsOrganized':   _orgSports,
          'bio':               _orgBioCtrl.text.trim(),
        });
      }

      await FirebaseFirestore.instance
          .collection('users').doc(_uid).update(data);
      // Email is kept off the publicly-readable profile doc — see
      // ContactService.
      await ContactService.write(uid: _uid, email: _email);

      Get.offAllNamed('/home');
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

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                begin: const Offset(0.08, 0), end: Offset.zero)
                .animate(anim),
            child: FadeTransition(opacity: anim, child: child)),
          child: KeyedSubtree(
              key: ValueKey<int>(_step),
              child: _step == 0 ? _buildStep1() : _buildStep2()),
        )),
      ])),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      if (_step > 0)
        GestureDetector(
          onTap: () => setState(() => _step--),
          child: Container(width: 38, height: 38,
            decoration: BoxDecoration(color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border)),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textPrimary, size: 16)),
        )
      else
        const SizedBox(width: 38),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Complete Your Profile', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 16,
          fontWeight: FontWeight.w800)),
        Text('Step ${_step + 1} of 2',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ]),
    ]),
  );

  Widget _buildProgressBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: List.generate(2, (i) => Expanded(
      child: Container(height: 4,
        margin: EdgeInsets.only(right: i < 1 ? 4 : 0),
        decoration: BoxDecoration(
          color: i <= _step ? AppTheme.accent : AppTheme.border,
          borderRadius: BorderRadius.circular(2)),
      ),
    ))),
  );

  // ── Step 1 — Choose Role ──────────────────

  Widget _buildStep1() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Welcome header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent)),
          child: Row(children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: FirebaseAuth
                  .instance.currentUser?.photoURL != null
                  ? NetworkImage(
                      FirebaseAuth.instance.currentUser!.photoURL!)
                  : null,
              backgroundColor: AppTheme.accent,
              child: FirebaseAuth.instance.currentUser?.photoURL == null
                  ? Text(_firstName.isNotEmpty ? _firstName[0] : 'G',
                      style: const TextStyle(color: AppTheme.buttonFg,
                          fontWeight: FontWeight.w800, fontSize: 18))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome, $_firstName! 👋', style: TextStyle(
                color: AppTheme.accentText, fontSize: 14,
                fontWeight: FontWeight.w800)),
              Text('Let\'s set up your athlete profile',
                  style: TextStyle(color: AppTheme.sub, fontSize: 12)),
            ])),
          ]),
        ),

        const SizedBox(height: 28),

        Text('I am a...', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 20,
          fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('Choose your role in the Legazpi sports community',
            style: TextStyle(color: AppTheme.sub, fontSize: 13)),

        const SizedBox(height: 24),

        // Role cards
        _RoleCard(
          emoji:       '🏃',
          title:       'Athlete',
          subtitle:    'I play sports and want to track my performance',
          isSelected:  _role == 'athlete',
          onTap:       () => setState(() => _role = 'athlete'),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji:       '🧢',
          title:       'Coach',
          subtitle:    'I coach athletes and want to discover talent',
          isSelected:  _role == 'coach',
          onTap:       () => setState(() => _role = 'coach'),
        ),
        const SizedBox(height: 12),
        _RoleCard(
          emoji:       '📋',
          title:       'Organizer',
          subtitle:    'I organize events and manage competitions',
          isSelected:  _role == 'organizer',
          onTap:       () => setState(() => _role = 'organizer'),
        ),

        const SizedBox(height: 32),
        const Spacer(),
        _PrimaryButton(
          label:  'Continue',
          onTap:  _canProceed() ? _nextStep : null),
      ]),
    );
  }

  // ── Step 2 — Role Details ─────────────────

  Widget _buildStep2() {
    switch (_role) {
      case 'athlete':  return _buildAthleteDetails();
      case 'coach':    return _buildCoachDetails();
      case 'organizer': return _buildOrganizerDetails();
      default:         return const SizedBox();
    }
  }

  // ── Athlete details ───────────────────────

  Widget _buildAthleteDetails() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(emoji: '🏃', title: 'Athlete Details',
            subtitle: 'Tell us about your sport'),
        const SizedBox(height: 20),

        const _Label('Barangay'),
        const SizedBox(height: 8),
        _BarangayButton(
          value: _selectedBarangay,
          onTap: _pickBarangay),
        const SizedBox(height: 16),

        const _Label('Sports you play'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kSports.map((s) {
            final sel = _selectedSports.contains(s);
            return _Chip(label: s, sel: sel,
              onTap: () => setState(() {
                sel ? _selectedSports.remove(s)
                    : _selectedSports.add(s);
                // Dropping a sport can orphan the position picked under it —
                // a Setter who stops playing volleyball isn't a Setter.
                if (!isKnownPosition(_position, _selectedSports)) {
                  _position = '';
                }
              }));
          }).toList()),
        const SizedBox(height: 16),

        const _Label('Position / Role'),
        const SizedBox(height: 8),
        _PositionButton(
          value: _position,
          icon: positionIcon(_position, _selectedSports),
          hasSport: _selectedSports.isNotEmpty,
          onTap: _pickPosition),
        const SizedBox(height: 16),

        const _Label('Years of Playing'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kYears.map((y) => _Chip(
            label: y, sel: _yearsOfPlaying == y,
            onTap: () =>
                setState(() => _yearsOfPlaying = y))).toList()),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Height (cm)'),
            const SizedBox(height: 8),
            _Field(ctrl: _heightCtrl, hint: 'e.g. 175',
              icon: Icons.height_rounded,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Label('Weight (kg)'),
            const SizedBox(height: 8),
            _Field(ctrl: _weightCtrl, hint: 'e.g. 70',
              icon: Icons.monitor_weight_outlined,
              keyboard: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
          ])),
        ]),
        const SizedBox(height: 16),

        const _Label('Open to Recruitment'),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(label: '✅  Yes', sel: _openToRecruitment,
              onTap: () => setState(() => _openToRecruitment = true)),
          const SizedBox(width: 8),
          _Chip(label: '❌  Not now', sel: !_openToRecruitment,
              onTap: () => setState(() => _openToRecruitment = false)),
        ]),
        const SizedBox(height: 32),
        const Spacer(),
        _PrimaryButton(
          label: _isLoading ? 'Saving...' : 'Finish Setup',
          onTap: _isLoading ? null : _nextStep),
      ]),
    );
  }

  // ── Coach details ─────────────────────────

  Widget _buildCoachDetails() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(emoji: '🧢', title: 'Coaching Info',
            subtitle: 'Tell us about your coaching experience'),
        const SizedBox(height: 20),

        const _Label('Barangay'),
        const SizedBox(height: 8),
        _BarangayButton(value: _selectedBarangay, onTap: _pickBarangay),
        const SizedBox(height: 16),

        const _Label('Sport You Coach'),
        const SizedBox(height: 8),
        // Single-select — see coach_register_screen.dart for why a coach gets
        // one sport. Still written as a one-element list, so `primarySports`
        // keeps the same shape every consumer already queries.
        Wrap(spacing: 8, runSpacing: 8,
          children: _kSports.map((s) {
            final sel = _coachSports.contains(s);
            return _Chip(label: s, sel: sel,
              onTap: () => setState(() =>
                  _coachSports..clear()..add(s)));
          }).toList()),
        const SizedBox(height: 16),

        const _Label('Coaching Level'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kLevels.map((l) => _Chip(
            label: l, sel: _coachingLevel == l,
            onTap: () =>
                setState(() => _coachingLevel = l))).toList()),
        const SizedBox(height: 16),

        const _Label('Years of Experience'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: ['1-2 Yrs', '3-5 Yrs', '5-10 Yrs', '10+ Yrs']
              .map((y) => _Chip(label: y, sel: _yearsOfExperience == y,
                onTap: () =>
                    setState(() => _yearsOfExperience = y))).toList()),
        const SizedBox(height: 16),

        const _Label('Team / Organization (Optional)'),
        const SizedBox(height: 8),
        _Field(ctrl: _teamOrgCtrl,
            hint: 'e.g. Legazpi City Basketball Team',
            icon: Icons.groups_outlined),
        const SizedBox(height: 32),
        const Spacer(),
        _PrimaryButton(
          label: _isLoading ? 'Saving...' : 'Finish Setup',
          onTap: _isLoading ? null : _nextStep),
      ]),
    );
  }

  // ── Organizer details ─────────────────────

  Widget _buildOrganizerDetails() {
    return FillViewportScroll(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(emoji: '📋', title: 'Organization Info',
            subtitle: 'Tell us about your organization'),
        const SizedBox(height: 20),

        const _Label('Barangay'),
        const SizedBox(height: 8),
        _BarangayButton(value: _selectedBarangay, onTap: _pickBarangay),
        const SizedBox(height: 16),

        const _Label('Organization Name'),
        const SizedBox(height: 8),
        _Field(ctrl: _orgNameCtrl,
            hint: 'e.g. Legazpi City Sports Council',
            icon: Icons.business_outlined),
        const SizedBox(height: 16),

        const _Label('Organization Type'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kOrgTypes.map((t) => _Chip(
            label: t, sel: _orgType == t,
            onTap: () =>
                setState(() => _orgType = t))).toList()),
        const SizedBox(height: 16),

        const _Label('Sports You Organize'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8,
          children: _kSports.map((s) {
            final sel = _orgSports.contains(s);
            return _Chip(label: s, sel: sel,
              onTap: () => setState(() =>
                  sel ? _orgSports.remove(s) : _orgSports.add(s)));
          }).toList()),
        const SizedBox(height: 32),
        const Spacer(),
        _PrimaryButton(
          label: _isLoading ? 'Saving...' : 'Finish Setup',
          onTap: _isLoading ? null : _nextStep),
      ]),
    );
  }
}

// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({required this.emoji, required this.title,
      required this.subtitle, required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.accentSurface : AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppTheme.accent : AppTheme.border,
          width: isSelected ? 2 : 1.5)),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent : AppTheme.cardNested,
            borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(emoji,
              style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
            color: isSelected
                ? AppTheme.accentText : AppTheme.textPrimary,
            fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(
              color: AppTheme.sub, fontSize: 12, height: 1.4)),
        ])),
        if (isSelected)
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.accent, size: 22),
      ]),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String emoji, title, subtitle;
  const _SectionHeader({required this.emoji, required this.title,
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
          fontSize: 17, fontWeight: FontWeight.w800)),
      Text(subtitle,
          style: TextStyle(color: AppTheme.sub, fontSize: 12)),
    ]),
  ]);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(color: AppTheme.textPrimary,
        fontSize: 13, fontWeight: FontWeight.w700));
}

class _BarangayButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _BarangayButton({required this.value, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: value.isNotEmpty ? AppTheme.accent : AppTheme.border,
          width: 1.5)),
      child: Row(children: [
        Icon(Icons.location_on_outlined,
          color: value.isNotEmpty ? AppTheme.accent : AppTheme.muted,
          size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(
          value.isNotEmpty ? value : 'Select Barangay (Legazpi City)',
          style: TextStyle(
            color: value.isNotEmpty
                ? AppTheme.textPrimary : AppTheme.muted,
            fontSize: 14))),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: AppTheme.muted, size: 20),
      ]),
    ),
  );
}

/// The position field, styled as a twin of [_BarangayButton] so the two
/// pickers in this form look alike. Kept as its own widget rather than adding
/// parameters to [_BarangayButton], to avoid touching that widget's existing
/// call sites.
///
/// [hasSport] gates the tap: the sheet lists positions per sport, so there is
/// nothing to show until at least one sport is selected above.
class _PositionButton extends StatelessWidget {
  final String value;
  /// The sport's own glyph — see positionIcon. Was always a basketball.
  final IconData icon;
  final bool hasSport;
  final VoidCallback onTap;
  const _PositionButton({required this.value, required this.icon,
      required this.hasSport, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: hasSport ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
          color: value.isNotEmpty ? AppTheme.accent : AppTheme.border,
          width: 1.5)),
      child: Row(children: [
        Icon(icon,
          color: value.isNotEmpty ? AppTheme.accent : AppTheme.muted,
          size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(
          value.isNotEmpty
              ? value
              : hasSport ? 'Select Position' : 'Select your sport first',
          style: TextStyle(
            color: value.isNotEmpty
                ? AppTheme.textPrimary : AppTheme.muted,
            fontSize: 14))),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: AppTheme.muted, size: 20),
      ]),
    ),
  );
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
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  const _Field({required this.ctrl, required this.hint,
      required this.icon, this.keyboard, this.formatters});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: keyboard,
    inputFormatters: formatters,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
      prefixIcon: Icon(icon, color: AppTheme.muted, size: 20),
      filled: true, fillColor: AppTheme.card,
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
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
      onPressed: onTap,
      child: Text(label)));
}
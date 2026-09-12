// lib/screens/profile/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../constants/sport_icons.dart';
import '../../constants/sport_positions.dart';
import '../../widgets/barangay_picker_sheet.dart';
import '../../widgets/position_picker_sheet.dart';
import '../../utils/error_messages.dart';
import '../../utils/sports.dart';

const _kRadius = 14.0;
const List<String> _kSports = ['Basketball', 'Volleyball', 'Badminton'];
const List<String> _kExperience = ['<1 Yr', '1-2 Yrs', '3-5 Yrs', '5+ Yrs'];
// Coaches answer these at sign-up (coach_register_screen.dart). They used to
// get the athlete list above here, so a coach who had said "5-10" or "10+"
// found no chip lit and could only step down to "5+".
const List<String> _kCoachExperience = [
  '1-2 Yrs', '3-5 Yrs', '5-10 Yrs', '10+ Yrs'];
const List<String> _kCoachLevels = ['Barangay', 'City', 'Provincial', 'National'];

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _uploadingPhoto = false;

  File? _pickedPhoto;
  String? _existingPhotoUrl;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  String _position = '';
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _barangay;
  final _bioCtrl = TextEditingController();
  List<String> _sports = [];
  String _experience = '';
  /// Coach only. Set at sign-up and, until this screen offered it, never
  /// changeable afterwards.
  String _coachingLevel = '';
  bool _openToRecruitment = false;
  String _role = '';
  List<String> _sportsOrganized = [];

  /// Coaches register their experience as `yearsOfExperience` and their
  /// profile view reads that field back; athletes use `yearsOfPlaying`.
  /// This screen used to read and write `yearsOfPlaying` for everyone, so a
  /// coach's Experience always loaded blank and saving it silently did nothing.
  String get _experienceField =>
      _role == 'coach' ? 'yearsOfExperience' : 'yearsOfPlaying';

  /// The same split for the bio. Coach sign-up writes `coachingBio`, and that
  /// is the field a coach's public profile shows athletes. This screen used to
  /// edit `bio` for everyone, so a coach's edits never reached athletes — and
  /// their own profile showed both texts.
  String get _bioField => _role == 'coach' ? 'coachingBio' : 'bio';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final data = doc.data() ?? {};
      _role = data['role'] as String? ?? '';
      _sportsOrganized =
          (data['sportsOrganized'] as List?)?.cast<String>().toList() ?? [];
      _firstNameCtrl.text = data['firstName'] as String? ?? '';
      _lastNameCtrl.text = data['lastName'] as String? ?? '';
      // Kept verbatim even when it's legacy free text that isn't in
      // kSportPositions: the picker is how positions get corrected, but
      // loading this screen shouldn't silently erase a value the user never
      // touched. The UI flags an unrecognized one instead.
      _position = data['position'] as String? ?? '';
      _heightCtrl.text = data['heightCm']?.toString() ?? '';
      _weightCtrl.text = data['weightKg']?.toString() ?? '';
      _barangay = data['barangay'] as String?;
      // Reads _role, like _experienceField below. A coach who edited their
      // bio before the fix has it in `bio`; show that rather than an empty
      // box if `coachingBio` is blank, so saving moves it where it belongs.
      final bio = (data[_bioField] as String? ?? '').trim();
      _bioCtrl.text =
          bio.isNotEmpty ? bio : (data['bio'] as String? ?? '').trim();
      // Reads _role, which is assigned above — keep that ordering.
      _experience = data[_experienceField] as String? ?? '';
      _coachingLevel = data['coachingLevel'] as String? ?? '';
      _openToRecruitment = data['openToRecruitment'] as bool? ?? false;
      _existingPhotoUrl = data['photoUrl'] as String?;
      _sports = sportsOf(data);
    } catch (_) {
      // fields just stay blank; user can fill them in
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (_firstNameCtrl.text.trim().isEmpty) {
      _snack('Name required', 'Please enter your first name.', isError: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      String? photoUrl = _existingPhotoUrl;
      if (_pickedPhoto != null) {
        setState(() => _uploadingPhoto = true);
        photoUrl = await StorageService.uploadProfilePhoto(_uid, _pickedPhoto!);
        setState(() => _uploadingPhoto = false);
      }

      await FirebaseFirestore.instance.collection('users').doc(_uid).update({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        // Registration writes `fullName` and a lot of screens (leaderboard,
        // events, admin review, the team carousel) read it in preference to
        // the name parts. This screen used to leave it untouched, so renaming
        // yourself changed first/last but every one of those screens kept
        // showing whoever you used to be.
        'fullName': '${_firstNameCtrl.text.trim()} '
            '${_lastNameCtrl.text.trim()}'.trim(),
        // Athlete-only, like openToRecruitment below: coaches and organizers
        // never see these fields, so saving their profile shouldn't stamp
        // three blank athlete values onto their document.
        if (_role == 'athlete') ...{
          'position': _position,
          'heightCm': _heightCtrl.text.trim(),
          'weightKg': _weightCtrl.text.trim(),
        },
        _bioField: _bioCtrl.text.trim(),
        // Clears the stray copy a coach's earlier edits left in `bio`, so
        // their own profile stops showing two different bios.
        if (_role == 'coach') 'bio': FieldValue.delete(),
        'barangay': _barangay ?? '',
        // Organizers no longer see either of these fields, so saving their
        // profile shouldn't stamp athlete values onto their document —
        // registration never creates them, and nothing organizer-facing reads
        // them back.
        if (_role != 'organizer') _experienceField: _experience,
        if (_role == 'coach' && _coachingLevel.isNotEmpty)
          'coachingLevel': _coachingLevel,
        // Recruitment is an athlete-only signal; coaches and organizers don't
        // see the toggle, so don't write a field they can't control.
        if (_role == 'athlete') 'openToRecruitment': _openToRecruitment,
        // Left untouched when nothing is selected, rather than cleared: an
        // empty list would hide an athlete from every coach's Scout, and
        // stop a coach from scouting at all.
        if (_role != 'organizer' && _sports.isNotEmpty) 'primarySports': _sports,
        if (_role == 'organizer') 'sportsOrganized': _sportsOrganized,
        if (photoUrl != null) 'photoUrl': photoUrl,
      });

      if (!mounted) return;
      Get.back();
      Get.snackbar(
        'Profile Updated',
        'Your changes have been saved.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText: AppTheme.accentText,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(title, msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
        colorText: isError ? const Color(0xFFFF5C5C) : AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3));
  }

  String _initials() {
    final f = _firstNameCtrl.text.isNotEmpty
        ? _firstNameCtrl.text[0].toUpperCase()
        : '';
    final l = _lastNameCtrl.text.isNotEmpty
        ? _lastNameCtrl.text[0].toUpperCase()
        : '';
    return '$f$l';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: const Center(
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border)),
                  child: Icon(Icons.close_rounded,
                      color: AppTheme.textPrimary, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Text('Edit Profile',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(children: [
                _buildPhotoPicker(),
                const SizedBox(height: 28),
                _label('First Name'),
                const SizedBox(height: 8),
                _field(_firstNameCtrl, 'e.g. John'),
                const SizedBox(height: 14),
                _label('Last Name'),
                const SizedBox(height: 8),
                _field(_lastNameCtrl, 'e.g. Doe'),
                const SizedBox(height: 14),
                // Athletes only. A coach has no playing position, height or
                // weight — only athlete registration collects these, and only
                // the athlete section of Settings displays them.
                if (_role == 'athlete') ...[
                  _label('Position'),
                  const SizedBox(height: 8),
                  _buildPositionPicker(),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Height (cm)'),
                          const SizedBox(height: 8),
                          _field(_heightCtrl, '175',
                              keyboardType: TextInputType.number),
                        ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Weight (kg)'),
                          const SizedBox(height: 8),
                          _field(_weightCtrl, '70',
                              keyboardType: TextInputType.number),
                        ])),
                  ]),
                  const SizedBox(height: 14),
                ],
                _label('Barangay'),
                const SizedBox(height: 8),
                _buildBarangayPicker(),
                const SizedBox(height: 14),
                // Named and sized as coach sign-up has it (200 characters),
                // so a coach's existing bio is never longer than the box.
                _label(_role == 'coach' ? 'Coaching Bio' : 'Bio'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  maxLength: _role == 'coach' ? 200 : 160,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'A short line about yourself...',
                    hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.card,
                    counterStyle: TextStyle(color: AppTheme.sub, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_kRadius),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_kRadius),
                        borderSide:
                            BorderSide(color: AppTheme.border, width: 1.5)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(_kRadius),
                        borderSide:
                            const BorderSide(color: AppTheme.accent, width: 1.5)),
                  ),
                ),
                // An organizer neither plays a sport nor has playing
                // experience here — their sport field is "Sports You Organize"
                // below, which is the one that actually gates event creation.
                // Showing both asked the same question twice, and the wrong
                // one was the one that did nothing.
                if (_role != 'organizer') ...[
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _label(_role == 'coach'
                          ? 'Sport You Coach'
                          : 'Sport(s) You Play')),
                  const SizedBox(height: 4),
                  if (_role == 'coach')
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Scouting only shows athletes from this sport.',
                          style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                    ),
                  const SizedBox(height: 8),
                  // Single-select for coaches (one coach, one sport — see
                  // coach_register_screen.dart), multi-select for athletes, who
                  // may genuinely play several.
                  //
                  // The coach arm deliberately does NOT truncate on load. An
                  // older version of this screen was single-choice and saved
                  // `[_sport]`, so a coach who already had two sports silently
                  // lost one by editing anything on this page — and with
                  // scouting gated on this field, that cut them off from half
                  // their athletes. Here a legacy two-sport coach sees both
                  // chips lit, because that is what is stored; it collapses to
                  // one only when they tap, which is a choice they made.
                  // Align, like the labels above: the parent Column centres
                  // its children, so a Wrap that breaks onto a second row
                  // would sit centred instead of flush under its label.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kSports
                          .map((s) => _chip(
                              s,
                              _sports.contains(s),
                              () => setState(() {
                                    if (_role == 'coach') {
                                      _sports = [s];
                                    } else if (_sports.contains(s)) {
                                      _sports.remove(s);
                                    } else {
                                      _sports.add(s);
                                    }
                                    // Dropping a sport can orphan the position
                                    // picked under it. Only clears a position
                                    // the picker itself produced — a legacy
                                    // free-text value is never in the list, and
                                    // wiping it on an unrelated sport tap would
                                    // be the silent data loss the load path
                                    // avoids.
                                    if (_position.isNotEmpty &&
                                        !isKnownPosition(_position, _sports) &&
                                        isCatalogPosition(_position)) {
                                      _position = '';
                                    }
                                  })))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _label('Experience')),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: (_role == 'coach'
                              ? _kCoachExperience
                              : _kExperience)
                          .map((e) => _chip(e, _experience == e,
                              () => setState(() => _experience = e)))
                          .toList(),
                    ),
                  ),
                  if (_role == 'coach') ...[
                    const SizedBox(height: 20),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: _label('Coaching Level')),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kCoachLevels
                            .map((l) => _chip(l, _coachingLevel == l,
                                () => setState(() => _coachingLevel = l)))
                            .toList(),
                      ),
                    ),
                  ],
                ],
                if (_role == 'organizer') ...[
                  const SizedBox(height: 20),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: _label('Sports You Organize')),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                        'Event creation only offers sports selected here.',
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kSports
                          .map((s) => _chip(
                              s,
                              _sportsOrganized.contains(s),
                              () => setState(() => _sportsOrganized.contains(s)
                                  ? _sportsOrganized.remove(s)
                                  : _sportsOrganized.add(s))))
                          .toList(),
                    ),
                  ),
                ],
                // Athletes only — a coach or organizer is never the one being
                // recruited, so the toggle would be meaningless to them.
                if (_role == 'athlete') ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(_kRadius),
                        border: Border.all(color: AppTheme.border)),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Open to Recruitment',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            Text('Let coaches know you\'re available',
                                style: TextStyle(
                                    color: AppTheme.sub, fontSize: 11)),
                          ])),
                      Switch(
                        value: _openToRecruitment,
                        activeThumbColor: AppTheme.accent,
                        onChanged: (v) =>
                            setState(() => _openToRecruitment = v),
                      ),
                    ]),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppTheme.buttonFg, strokeWidth: 2))
                        : Text(_uploadingPhoto
                            ? 'Uploading photo...'
                            : 'Save Changes'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(children: [
        Container(
          width: 104,
          height: 104,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.accent, AppTheme.accent2]),
          ),
          child: ClipOval(
            child: _pickedPhoto != null
                ? Image.file(_pickedPhoto!, fit: BoxFit.cover)
                : (_existingPhotoUrl != null
                    ? Image.network(_existingPhotoUrl!, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                            child: Text(_initials(),
                                style: const TextStyle(
                                    color: AppTheme.buttonFg,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900))))
                    : Center(
                        child: Text(_initials(),
                            style: const TextStyle(
                                color: AppTheme.buttonFg,
                                fontSize: 32,
                                fontWeight: FontWeight.w900)))),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.bg, width: 3)),
            child: const Icon(Icons.edit_rounded,
                color: AppTheme.buttonFg, size: 15),
          ),
        ),
      ]),
    );
  }

  Widget _label(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Text(text,
          style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700)));

  Widget _field(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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

  Widget _buildBarangayPicker() {
    final hasValue = _barangay != null && _barangay!.isNotEmpty;
    return GestureDetector(
      onTap: () async {
        final picked =
            await showBarangayPickerSheet(context, selected: _barangay);
        if (picked != null) setState(() => _barangay = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(
                color: hasValue ? AppTheme.accent : AppTheme.border,
                width: 1.5)),
        child: Row(children: [
          Icon(Icons.location_on_outlined,
              color: hasValue ? AppTheme.accent : AppTheme.muted, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(hasValue ? _barangay! : 'Select Barangay',
                  style: TextStyle(
                      color: hasValue ? AppTheme.textPrimary : AppTheme.muted,
                      fontSize: 14))),
          Icon(Icons.keyboard_arrow_down_rounded,
              color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }

  /// Twin of [_buildBarangayPicker], for the athlete-only Position field.
  ///
  /// Two states the barangay picker doesn't have: the tile is inert until a
  /// sport is selected (the sheet is per-sport, so there'd be nothing to
  /// show), and a stored value that isn't in the catalog gets a note under it.
  /// That note is the whole legacy story — accounts created before the picker
  /// keep their hand-typed position until the owner replaces it here.
  Widget _buildPositionPicker() {
    final hasValue = _position.isNotEmpty;
    final hasSport = _sports.isNotEmpty;
    final isLegacy = hasValue && !isCatalogPosition(_position);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: !hasSport
            ? null
            : () async {
                final picked = await showPositionPickerSheet(context,
                    sports: _sports, selected: _position);
                if (picked != null) setState(() => _position = picked);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                  color: hasValue ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
          child: Row(children: [
            Icon(positionIcon(_position, _sports),
                color: hasValue ? AppTheme.accent : AppTheme.muted, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(
                    hasValue
                        ? _position
                        : hasSport
                            ? 'Select Position'
                            : 'Select your sport first',
                    style: TextStyle(
                        color: hasValue ? AppTheme.textPrimary : AppTheme.muted,
                        fontSize: 14))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.muted, size: 20),
          ]),
        ),
      ),
      if (isLegacy) ...[
        const SizedBox(height: 6),
        Text('Not a recognized position — tap to update.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      ],
    ]);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
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
        child: Text(label,
            style: TextStyle(
                color: sel ? AppTheme.accentText : AppTheme.muted,
                fontSize: 13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }
}
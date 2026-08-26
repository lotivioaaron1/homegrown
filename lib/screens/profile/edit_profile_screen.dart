// lib/screens/profile/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../services/storage_service.dart';
import '../../widgets/barangay_picker_sheet.dart';

const _kRadius = 14.0;
const List<String> _kSports = ['Basketball', 'Volleyball', 'Badminton'];
const List<String> _kExperience = ['<1 Yr', '1-2 Yrs', '3-5 Yrs', '5+ Yrs'];

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
  final _positionCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _barangay;
  final _bioCtrl = TextEditingController();
  String _sport = '';
  String _experience = '';
  bool _openToRecruitment = false;
  String _role = '';
  List<String> _sportsOrganized = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _positionCtrl.dispose();
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
      _positionCtrl.text = data['position'] as String? ?? '';
      _heightCtrl.text = data['heightCm']?.toString() ?? '';
      _weightCtrl.text = data['weightKg']?.toString() ?? '';
      _barangay = data['barangay'] as String?;
      _bioCtrl.text = data['bio'] as String? ?? '';
      _experience = data['yearsOfPlaying'] as String? ?? '';
      _openToRecruitment = data['openToRecruitment'] as bool? ?? false;
      _existingPhotoUrl = data['photoUrl'] as String?;
      final sports = (data['primarySports'] as List?)?.cast<String>();
      _sport = sports != null && sports.isNotEmpty ? sports.first : '';
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
        'position': _positionCtrl.text.trim(),
        'heightCm': _heightCtrl.text.trim(),
        'weightKg': _weightCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'barangay': _barangay ?? '',
        'yearsOfPlaying': _experience,
        'openToRecruitment': _openToRecruitment,
        if (_sport.isNotEmpty) 'primarySports': [_sport],
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
      _snack('Error', e.toString(), isError: true);
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
                _label('Position'),
                const SizedBox(height: 8),
                _field(_positionCtrl, 'e.g. Setter'),
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
                _label('Barangay'),
                const SizedBox(height: 8),
                _buildBarangayPicker(),
                const SizedBox(height: 14),
                _label('Bio'),
                const SizedBox(height: 8),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  maxLength: 160,
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
                            BorderSide(color: AppTheme.accent, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                    alignment: Alignment.centerLeft,
                    child: _label('Sport')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _kSports
                      .map((s) => _chip(s, _sport == s,
                          () => setState(() => _sport = s)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Align(
                    alignment: Alignment.centerLeft,
                    child: _label('Experience')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _kExperience
                      .map((e) => _chip(e, _experience == e,
                          () => setState(() => _experience = e)))
                      .toList(),
                ),
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
                  Wrap(
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
                ],
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
                      activeColor: AppTheme.accent,
                      onChanged: (v) =>
                          setState(() => _openToRecruitment = v),
                    ),
                  ]),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? SizedBox(
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
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
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
            borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
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
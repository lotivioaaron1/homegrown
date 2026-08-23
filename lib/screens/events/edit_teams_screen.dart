// lib/screens/events/edit_teams_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';

/// Lets an organizer name two teams and assign each registered player to
/// one, for an event that was created before team-based stat entry
/// existed (or one where the organizer just wants to change the split).
/// Add Stats and Record Match both read this same `team` field once saved.
class EditTeamsScreen extends StatefulWidget {
  const EditTeamsScreen({super.key});
  @override
  State<EditTeamsScreen> createState() => _EditTeamsScreenState();
}

class _EditTeamsScreenState extends State<EditTeamsScreen> {
  String get _eventId => (Get.arguments as Map?)?['eventId'] as String? ?? '';

  final _teamACtrl = TextEditingController();
  final _teamBCtrl = TextEditingController();
  List<Map<String, dynamic>> _players = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _teamACtrl.dispose();
    _teamBCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('events').doc(_eventId).get();
    final data = doc.data() ?? {};
    _teamACtrl.text = data['teamAName'] as String? ?? '';
    _teamBCtrl.text = data['teamBName'] as String? ?? '';
    _players = ((data['players'] as List?) ?? [])
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
    for (final p in _players) {
      p['team'] ??= 'A';
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final teamAName = _teamACtrl.text.trim().isEmpty
          ? 'Team A' : _teamACtrl.text.trim();
      final teamBName = _teamBCtrl.text.trim().isEmpty
          ? 'Team B' : _teamBCtrl.text.trim();
      await FirebaseFirestore.instance.collection('events').doc(_eventId).update({
        'teamAName': teamAName,
        'teamBName': teamBName,
        'players': _players,
      });
      if (!mounted) return;
      Get.back();
      Get.snackbar('Teams Updated', 'Roster split saved.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.accentSurface,
          colorText: AppTheme.accentText,
          margin: const EdgeInsets.all(16), borderRadius: 12,
          duration: const Duration(seconds: 3));
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFF2A1A1A),
          colorText: AppTheme.error,
          margin: const EdgeInsets.all(16), borderRadius: 12);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2))
            : Column(children: [
                _buildTopBar(),
                Expanded(child: _buildContent()),
              ]),
      ),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Text('Edit Teams', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 18,
          fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('TEAM NAMES', style: TextStyle(
            color: AppTheme.muted, fontSize: 12,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _teamNameField(_teamACtrl, 'Team A name')),
          const SizedBox(width: 10),
          Expanded(child: _teamNameField(_teamBCtrl, 'Team B name')),
        ]),
        const SizedBox(height: 20),
        Text('ASSIGN PLAYERS', style: TextStyle(
            color: AppTheme.muted, fontSize: 12,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 10),
        if (_players.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              Icon(Icons.groups_outlined, color: AppTheme.muted, size: 28),
              const SizedBox(height: 8),
              Text('No players registered',
                  style: TextStyle(color: AppTheme.sub, fontSize: 13)),
            ]),
          )
        else
          Container(
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: _players.asMap().entries.map((e) {
              final isLast = e.key == _players.length - 1;
              final p = e.value;
              final fullName = p['fullName'] as String? ?? '';
              final position = p['position'] as String? ?? '';
              final initials = fullName.trim().split(' ')
                  .where((s) => s.isNotEmpty).take(2)
                  .map((s) => s[0]).join().toUpperCase();
              return Container(
                decoration: BoxDecoration(border: Border(
                    bottom: isLast
                        ? BorderSide.none
                        : BorderSide(color: AppTheme.border))),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.accent, AppTheme.accent2]),
                      shape: BoxShape.circle),
                    child: Center(child: Text(initials, style: const TextStyle(
                        color: AppTheme.buttonFg, fontSize: 12,
                        fontWeight: FontWeight.w800))),
                  ),
                  title: Text(fullName, style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13,
                      fontWeight: FontWeight.w600)),
                  subtitle: position.isNotEmpty
                      ? Text(position,
                          style: TextStyle(color: AppTheme.sub, fontSize: 11))
                      : null,
                  trailing: _teamToggle(p),
                ),
              );
            }).toList()),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _isSaving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: AppTheme.buttonFg, strokeWidth: 2))
                : Text('Save Changes', style: TextStyle(
                    color: AppTheme.buttonFg, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _teamNameField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
      prefixIcon: Icon(Icons.groups_outlined, color: AppTheme.muted, size: 18),
      filled: true, fillColor: AppTheme.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.border, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
    ),
  );

  Widget _teamToggle(Map<String, dynamic> p) {
    final team = p['team'] as String? ?? 'A';
    Widget seg(String value) => GestureDetector(
      onTap: () => setState(() => p['team'] = value),
      child: Container(
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: team == value ? AppTheme.accentSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(6)),
        child: Text(value, style: TextStyle(
            color: team == value ? AppTheme.accentText : AppTheme.muted,
            fontSize: 11, fontWeight: FontWeight.w700))));
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [seg('A'), seg('B')]));
  }
}

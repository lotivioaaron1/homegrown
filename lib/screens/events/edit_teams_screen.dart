// lib/screens/events/edit_teams_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../services/team_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_messages.dart';
import '../../widgets/member_profiles.dart';
import '../../widgets/player_avatar.dart';

/// Lets an organizer rename an event's two teams. Players are listed under
/// their team but can't be moved: each player's team comes from their
/// coach's roster, and a player belongs to only one.
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
      });
      if (!mounted) return;
      Get.back();
      Get.snackbar('Teams Updated', 'Team names saved.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.accentSurface,
          colorText: AppTheme.accentText,
          margin: const EdgeInsets.all(16), borderRadius: 12,
          duration: const Duration(seconds: 3));
    } catch (e) {
      Get.snackbar('Error', friendlyError(e),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.errorSurface,
          colorText: AppTheme.errorText,
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
      Text('Rename Teams', style: TextStyle(
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
        Text('PLAYERS', style: TextStyle(
            color: AppTheme.muted, fontSize: 12,
            fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text("Players come from each coach's roster and stay on that team.",
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
        const SizedBox(height: 12),
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
          // The event's `players[]` carries no photo and a name frozen at
          // creation time, so the rows read the live user docs — the same
          // treatment the event detail roster gets, so the two agree.
          MemberProfilesBuilder(
            uids: _players.map((p) => p['uid'] as String? ?? '').toList(),
            builder: (context, profiles) {
              final unassigned = _players
                  .where((p) => p['team'] != 'A' && p['team'] != 'B')
                  .toList();
              return Column(children: [
                _teamGroup(_teamLabel('A'),
                    _players.where((p) => p['team'] == 'A').toList(), profiles),
                _teamGroup(_teamLabel('B'),
                    _players.where((p) => p['team'] == 'B').toList(), profiles),
                if (unassigned.isNotEmpty)
                  _teamGroup('Not on a team', unassigned, profiles),
              ]);
            },
          ),
        const SizedBox(height: 8),
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
                : const Text('Save Changes', style: TextStyle(
                    color: AppTheme.buttonFg, fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _teamNameField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    onChanged: (_) => setState(() {}),
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
          borderSide: const BorderSide(color: AppTheme.accent, width: 1.5)),
    ),
  );

  String _teamLabel(String value) {
    final typed = (value == 'A' ? _teamACtrl : _teamBCtrl).text.trim();
    return typed.isNotEmpty ? typed : 'Team $value';
  }

  Widget _teamGroup(String label, List<Map<String, dynamic>> players,
      Map<String, Map<String, dynamic>> profiles) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14,
                  fontWeight: FontWeight.w800))),
          Text('${players.length} player${players.length == 1 ? '' : 's'}',
              style: TextStyle(color: AppTheme.sub, fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border)),
          child: players.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No players on this team',
                      style: TextStyle(color: AppTheme.sub, fontSize: 13)),
                )
              : Column(children: [
                  for (var i = 0; i < players.length; i++)
                    _playerTile(players[i], profiles,
                        isLast: i == players.length - 1),
                ]),
        ),
      ]),
    );
  }

  Widget _playerTile(Map<String, dynamic> p,
      Map<String, Map<String, dynamic>> profiles, {required bool isLast}) {
    final position = p['position'] as String? ?? '';
    final identity = resolveMemberIdentity(profiles[p['uid'] as String? ?? ''],
        fallbackName: p['fullName'] as String? ?? '');
    return Container(
      decoration: BoxDecoration(border: Border(
          bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border))),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: PlayerAvatar(
            name: identity.name,
            photoUrl: identity.photoUrl,
            size: 36, fontSize: 12),
        title: Text(identity.name, style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 13,
            fontWeight: FontWeight.w600)),
        subtitle: position.isNotEmpty
            ? Text(position,
                style: TextStyle(color: AppTheme.sub, fontSize: 11))
            : null,
      ),
    );
  }
}

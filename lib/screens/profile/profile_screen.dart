// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/theme_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Initials ──────────────────────────────

  String _initials(String first, String last) {
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty  ? last[0].toUpperCase()  : '';
    return '$f$l';
  }

  // ── Sign out confirm ──────────────────────

  void _confirmSignOut(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('🚪', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text('Sign Out?', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 18,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('You will be returned to the login screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: SizedBox(height: 50,
              child: OutlinedButton(
                onPressed: () => Get.back(),
                child: Text('Cancel', style: TextStyle(
                    color: AppTheme.sub, fontWeight: FontWeight.w600))),
            )),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Get.back();
                  AuthController.to.signOut();
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5C5C),
                    foregroundColor: Colors.white),
                child: const Text('Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w700))),
            )),
          ]),
        ]),
      ),
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users').doc(_uid).snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2.5));
            }

            final data      = snap.data?.data() as Map<String, dynamic>? ?? {};
            final role      = data['role']      as String? ?? 'athlete';
            final firstName = data['firstName'] as String? ?? '';
            final lastName  = data['lastName']  as String? ?? '';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── Top bar ───────────────
                Row(children: [
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
                  Text('My Profile', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 18,
                      fontWeight: FontWeight.w800)),
                ]),

                const SizedBox(height: 24),

                // ── Avatar section ────────
                _buildAvatarSection(firstName, lastName, data, role),

                const SizedBox(height: 24),

                // ── Role-specific info ────
                if (role == 'athlete') ...[
                  _buildStatsSection(data),
                  const SizedBox(height: 16),
                  _buildAthleteInfoSection(data),
                ] else if (role == 'coach') ...[
                  _buildCoachInfoSection(data),
                ] else ...[
                  _buildOrganizerInfoSection(data),
                ],

                const SizedBox(height: 16),

                // ── Settings ──────────────
                _buildSettingsSection(context),

                const SizedBox(height: 16),

                // ── Sign out ──────────────
                _buildSignOutSection(context),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Avatar section ────────────────────────

  Widget _buildAvatarSection(String firstName, String lastName,
      Map<String, dynamic> data, String role) {
    final sport = role == 'organizer'
        ? (data['sportsOrganized'] as List?)?.isNotEmpty == true
            ? (data['sportsOrganized'] as List).first as String : ''
        : (data['primarySports'] as List?)?.isNotEmpty == true
            ? (data['primarySports'] as List).first as String : '';

    final emoji = role == 'athlete' ? '🏃'
        : role == 'coach' ? '🧢' : '📋';
    final roleLabel = role == 'athlete' ? 'Athlete'
        : role == 'coach' ? 'Coach' : 'Organizer';
    final subLabel = role == 'organizer'
        ? data['organization'] as String? ?? ''
        : role == 'coach'
            ? '${data['coachingLevel'] ?? ''} · ${data['yearsOfExperience'] ?? ''} Exp'
            : '${data['position'] ?? ''} · ${data['barangay'] ?? ''}';

    return Column(children: [
      // Avatar circle
      Stack(children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppTheme.accent, AppTheme.accent2]),
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.accent, width: 2),
            boxShadow: [BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.3),
              blurRadius: 20, spreadRadius: 2)],
          ),
          child: Center(child: Text(
            _initials(firstName, lastName),
            style: const TextStyle(color: AppTheme.buttonFg,
                fontSize: 28, fontWeight: FontWeight.w900))),
        ),
        Positioned(bottom: 2, right: 2,
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: AppTheme.accent, shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bg, width: 2)),
            child: const Icon(Icons.edit_rounded,
                color: AppTheme.buttonFg, size: 13)),
        ),
      ]),

      const SizedBox(height: 12),

      Text('$firstName $lastName', style: TextStyle(
        color: AppTheme.textPrimary, fontSize: 20,
        fontWeight: FontWeight.w900, letterSpacing: -0.3)),

      const SizedBox(height: 4),

      Text(subLabel, style: TextStyle(color: AppTheme.sub, fontSize: 13)),

      const SizedBox(height: 8),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.accentSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent)),
        child: Text(
          '$emoji  ${sport.isNotEmpty ? '$roleLabel · $sport' : roleLabel}',
          style: TextStyle(color: AppTheme.accentText,
              fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  // ── Stats section (Athlete) ───────────────

  Widget _buildStatsSection(Map<String, dynamic> data) {
    final pts = _toInt(data['points']);
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .get(),
      builder: (context, rankSnap) {
        String rank = '#—';
        if (rankSnap.hasData) {
          final list = rankSnap.data!.docs
              .map((d) => d.data() as Map<String, dynamic>)
              .toList()
            ..sort((a, b) =>
                _toInt(b['points']).compareTo(_toInt(a['points'])));
          final idx = list.indexWhere((a) => a['uid'] == _uid);
          if (idx >= 0) rank = '#${idx + 1}';
        }
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('stats')
              .where('athleteId', isEqualTo: _uid)
              .get(),
          builder: (context, snap) {
            final games = snap.data?.docs.length ?? 0;
            return Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              _sectionLabel('Performance'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border)),
                child: Column(children: [
                  _infoRow(icon: '⭐', iconBg: AppTheme.accentSurface,
                    label: 'Total Points', value: '$pts pts',
                    valueColor: AppTheme.accent),
                  _infoRow(icon: '🏆', iconBg: AppTheme.accentSurface,
                    label: 'City Rank', value: rank,
                    valueColor: AppTheme.accent),
                  _infoRow(icon: '🎮', iconBg: AppTheme.cardNested,
                    label: 'Games Played', value: '$games games',
                    isLast: true),
                ]),
              ),
            ]);
          },
        );
      },
    );
  }

  // ── Athlete info section ──────────────────

  Widget _buildAthleteInfoSection(Map<String, dynamic> data) {
    final sports   = (data['primarySports'] as List?)
        ?.map((e) => e.toString()).join(', ') ?? '—';
    final position = data['position']          as String? ?? '—';
    final years    = data['yearsOfPlaying']    as String? ?? '—';
    final height   = data['heightCm']          as String? ?? '—';
    final weight   = data['weightKg']          as String? ?? '—';
    final barangay = data['barangay']          as String? ?? '—';
    final isOpen   = data['openToRecruitment'] as bool?   ?? false;
    final bio      = data['bio']               as String? ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Athletic Profile'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          _infoRow(icon: '🏀', iconBg: AppTheme.accentSurface,
              label: 'Sport', value: sports),
          _infoRow(icon: '🎯', iconBg: AppTheme.cardNested,
              label: 'Position', value: position),
          _infoRow(icon: '⏱', iconBg: AppTheme.cardNested,
              label: 'Experience', value: years),
          _infoRow(icon: '📏', iconBg: AppTheme.cardNested,
              label: 'Height / Weight', value: '${height}cm / ${weight}kg'),
          _infoRow(icon: '📍', iconBg: AppTheme.cardNested,
              label: 'Barangay', value: barangay),
          _infoRow(
            icon: isOpen ? '✅' : '❌',
            iconBg: isOpen ? const Color(0xFF0D2E20) : AppTheme.cardNested,
            label: 'Open to Recruitment',
            value: isOpen ? 'Yes' : 'No',
            valueColor: isOpen ? AppTheme.success : AppTheme.muted,
            isLast: bio.isEmpty),
          if (bio.isNotEmpty)
            _bioRow(bio),
        ]),
      ),
    ]);
  }

  // ── Coach info section ────────────────────

  Widget _buildCoachInfoSection(Map<String, dynamic> data) {
    final level  = data['coachingLevel']     as String? ?? '—';
    final years  = data['yearsOfExperience'] as String? ?? '—';
    final org    = data['teamOrganization']  as String? ?? '—';
    final sports = (data['primarySports'] as List?)
        ?.map((e) => e.toString()).join(', ') ?? '—';
    final certs  = data['certifications']    as String? ?? '';
    final bio    = data['coachingBio']       as String? ?? '';
    final bgy    = data['barangay']          as String? ?? '—';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Coaching Info'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          _infoRow(icon: '🏅', iconBg: AppTheme.accentSurface,
              label: 'Coaching Level', value: level,
              valueColor: AppTheme.accent),
          _infoRow(icon: '⏱', iconBg: AppTheme.cardNested,
              label: 'Experience', value: years),
          _infoRow(icon: '🏫', iconBg: AppTheme.cardNested,
              label: 'Team / Organization', value: org),
          _infoRow(icon: '🏀', iconBg: AppTheme.accentSurface,
              label: 'Sport', value: sports),
          _infoRow(icon: '📍', iconBg: AppTheme.cardNested,
              label: 'Barangay', value: bgy),
          if (certs.isNotEmpty)
            _infoRow(icon: '🏆', iconBg: AppTheme.cardNested,
                label: 'Certifications', value: certs),
          if (bio.isNotEmpty)
            _bioRow(bio),
          if (bio.isEmpty && certs.isEmpty)
            _infoRow(icon: '📝', iconBg: AppTheme.cardNested,
                label: 'Bio', value: 'Not set', isLast: true),
        ]),
      ),
    ]);
  }

  // ── Organizer info section ────────────────

  Widget _buildOrganizerInfoSection(Map<String, dynamic> data) {
    final org      = data['organization']     as String? ?? '—';
    final orgType  = data['organizationType'] as String? ?? '—';
    final sports   = (data['sportsOrganized'] as List?)
        ?.map((e) => e.toString()).join(', ') ?? '—';
    final certs    = data['certifications']   as String? ?? '';
    final bio      = data['bio']              as String? ?? '';
    final bgy      = data['barangay']         as String? ?? '—';

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('events')
          .where('organizerId', isEqualTo: _uid)
          .get(),
      builder: (context, snap) {
        final eventCount = snap.data?.docs.length ?? 0;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Organization'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              _infoRow(icon: '🏢', iconBg: AppTheme.accentSurface,
                  label: 'Organization', value: org,
                  valueColor: AppTheme.accent),
              _infoRow(icon: '🏷', iconBg: AppTheme.cardNested,
                  label: 'Type', value: orgType),
              _infoRow(icon: '📅', iconBg: AppTheme.accentSurface,
                  label: 'Events Created', value: '$eventCount events',
                  valueColor: AppTheme.accent),
              _infoRow(icon: '⚽', iconBg: AppTheme.cardNested,
                  label: 'Sports Organized', value: sports),
              _infoRow(icon: '📍', iconBg: AppTheme.cardNested,
                  label: 'Barangay', value: bgy),
              if (certs.isNotEmpty)
                _infoRow(icon: '🏆', iconBg: AppTheme.cardNested,
                    label: 'Certifications', value: certs),
              if (bio.isNotEmpty)
                _bioRow(bio)
              else
                _infoRow(icon: '📝', iconBg: AppTheme.cardNested,
                    label: 'Bio', value: 'Not set', isLast: true),
            ]),
          ),
        ]);
      },
    );
  }

  // ── Settings section ──────────────────────

  Widget _buildSettingsSection(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Settings'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          // Dark mode toggle
          Obx(() {
            final isDark = ThemeController.to.isDark.value;
            return _settingsRow(
              icon:    isDark ? '☀️' : '🌙',
              label:   'Dark Mode',
              trailing: Switch(
                value:          isDark,
                onChanged:      (_) => ThemeController.to.toggleTheme(),
                activeColor:    AppTheme.accent,
                inactiveThumbColor: AppTheme.muted,
                inactiveTrackColor: AppTheme.border,
              ),
            );
          }),
          // Notifications (coming soon)
          _settingsRow(
            icon:     '🔔',
            label:    'Notifications',
            sub:      'Coming soon',
            trailing: Icon(Icons.chevron_right_rounded,
                color: AppTheme.muted, size: 20),
            isLast:   true,
          ),
        ]),
      ),
    ]);
  }

  // ── Sign out section ──────────────────────

  Widget _buildSignOutSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        const Color(0xFF2A1A1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFFFF5C5C).withValues(alpha: 0.4))),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3A1A1A),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.logout_rounded,
                color: Color(0xFFFF5C5C), size: 18)),
          const SizedBox(width: 12),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sign Out', style: TextStyle(
                color:      Color(0xFFFF5C5C),
                fontSize:   14,
                fontWeight: FontWeight.w700)),
              Text('Return to login screen', style: TextStyle(
                  color: Color(0xFF8888AA), fontSize: 11)),
            ])),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFFFF5C5C), size: 20),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Row builders
  // ─────────────────────────────────────────

  Widget _infoRow({
    required String icon,
    required Color  iconBg,
    required String label,
    required String value,
    Color?          valueColor,
    bool            isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border(
        bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: iconBg,
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(icon,
                style: const TextStyle(fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(
            color:      AppTheme.textPrimary,
            fontSize:   13,
            fontWeight: FontWeight.w500))),
          Flexible(child: Text(value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:      valueColor ?? AppTheme.sub,
              fontSize:   12,
              fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _bioRow(String bio) {
    return Container(
      decoration: BoxDecoration(border: Border(
          top: BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bio', style: TextStyle(
              color: AppTheme.sub, fontSize: 11,
              fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(bio, style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
          ]),
      ),
    );
  }

  Widget _settingsRow({
    required String  icon,
    required String  label,
    String?          sub,
    required Widget  trailing,
    bool             isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(border: Border(
        bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: AppTheme.cardNested,
                borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text(icon,
                style: const TextStyle(fontSize: 14)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 13,
                fontWeight: FontWeight.w500)),
              if (sub != null)
                Text(sub, style: TextStyle(
                    color: AppTheme.muted, fontSize: 10)),
            ])),
          trailing,
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text.toUpperCase(), style: TextStyle(
        color:         AppTheme.muted,
        fontSize:      10,
        fontWeight:    FontWeight.w700,
        letterSpacing: 1)),
    );
  }

  // ── Helpers ───────────────────────────────

  int _toInt(dynamic v) {
    if (v is int)    return v;
    if (v is double) return v.toInt();
    return 0;
  }
}
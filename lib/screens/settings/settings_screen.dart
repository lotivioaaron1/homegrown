// lib/screens/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/app_links.dart';
import '../../theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/theme_controller.dart';
import '../profile/edit_profile_screen.dart';

/// Everything that used to sit on the profile screen: Edit Profile,
/// role-specific details, Performance, Best Game, Dark Mode, and Sign Out.
/// Firestore queries are the same ones the old profile used — this is a
/// relocation, not new logic.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(_uid)
              .snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2.5),
              );
            }
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final role = data['role'] as String? ?? 'athlete';

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Row(children: [
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: AppTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border)),
                      child: Icon(LucideIcons.arrowLeft,
                          color: AppTheme.textPrimary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Settings',
                      style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 24),

                _editProfileCard(),
                const SizedBox(height: 16),

                if (role == 'athlete') ...[
                  _buildAthleteInfoSection(data),
                  const SizedBox(height: 16),
                  _buildStatsSection(data),
                  const SizedBox(height: 16),
                  _buildBestGameSection(),
                  const SizedBox(height: 16),
                ] else if (role == 'coach') ...[
                  _buildCoachInfoSection(data),
                  const SizedBox(height: 16),
                ] else ...[
                  _buildOrganizerInfoSection(data),
                  const SizedBox(height: 16),
                ],

                _buildSettingsSection(),
                const SizedBox(height: 16),
                _buildSignOutSection(context),
                const SizedBox(height: 12),
                _buildDeleteAccountRow(),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Edit Profile entry ─────────────────────────────────────────────────
  Widget _editProfileCard() {
    return GestureDetector(
      onTap: () => Get.to(() => const EditProfileScreen()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(LucideIcons.pencil, color: AppTheme.accent, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Profile',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Name, photo, bio and athletic details',
                    style: TextStyle(color: AppTheme.sub, fontSize: 11)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }

  // ── Athlete details ────────────────────────────────────────────────────
  Widget _buildAthleteInfoSection(Map<String, dynamic> data) {
    final sports = (data['primarySports'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '—';
    final position = data['position'] as String? ?? '—';
    final years = data['yearsOfPlaying'] as String? ?? '—';
    final height = data['heightCm'] as String? ?? '—';
    final weight = data['weightKg'] as String? ?? '—';
    final barangay = data['barangay'] as String? ?? '—';
    final isOpen = data['openToRecruitment'] as bool? ?? false;
    final bio = data['bio'] as String? ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Athletic Profile'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          _infoRow(
              icon: LucideIcons.volleyball,
              iconBg: AppTheme.accentSurface,
              iconColor: AppTheme.accent,
              label: 'Sport',
              value: sports),
          _infoRow(
              icon: LucideIcons.target,
              iconBg: AppTheme.cardNested,
              label: 'Position',
              value: position),
          _infoRow(
              icon: LucideIcons.clock,
              iconBg: AppTheme.cardNested,
              label: 'Experience',
              value: years),
          _infoRow(
              icon: LucideIcons.ruler,
              iconBg: AppTheme.cardNested,
              label: 'Height / Weight',
              value: '${height}cm / ${weight}kg'),
          _infoRow(
              icon: LucideIcons.mapPin,
              iconBg: AppTheme.cardNested,
              label: 'Barangay',
              value: barangay),
          _infoRow(
              icon: isOpen ? LucideIcons.checkCircle : LucideIcons.xCircle,
              iconBg: isOpen ? AppTheme.successSurface : AppTheme.cardNested,
              iconColor: isOpen ? AppTheme.successText : AppTheme.muted,
              label: 'Open to Recruitment',
              value: isOpen ? 'Yes' : 'No',
              valueColor: isOpen ? AppTheme.successText : AppTheme.muted,
              isLast: bio.isEmpty),
          if (bio.isNotEmpty) _bioRow(bio),
        ]),
      ),
    ]);
  }

  // ── Performance ────────────────────────────────────────────────────────
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
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('Performance'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                        color: AppTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.border)),
                    child: Column(children: [
                      _infoRow(
                          icon: LucideIcons.star,
                          iconBg: AppTheme.accentSurface,
                          iconColor: AppTheme.accent,
                          label: 'Total Points',
                          value: '$pts pts',
                          valueColor: AppTheme.accentText),
                      _infoRow(
                          icon: LucideIcons.trophy,
                          iconBg: AppTheme.accentSurface,
                          iconColor: AppTheme.accent,
                          label: 'City Rank',
                          value: rank,
                          valueColor: AppTheme.accentText),
                      _infoRow(
                          icon: LucideIcons.gamepad2,
                          iconBg: AppTheme.cardNested,
                          label: 'Games Played',
                          value: '$games games',
                          isLast: true),
                    ]),
                  ),
                ]);
          },
        );
      },
    );
  }

  // ── Best Game ──────────────────────────────────────────────────────────
  Widget _buildBestGameSection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('stats')
          .where('athleteId', isEqualTo: _uid)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final docs = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .toList()
          ..sort((a, b) => _toInt(b['pointsAwarded'])
              .compareTo(_toInt(a['pointsAwarded'])));
        final best = docs.first;
        final pts = _toInt(best['pointsAwarded']);
        final eventName = best['eventName'] as String? ?? '';
        final sport = best['sport'] as String? ?? '';
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Best Game'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.accent)),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.accent)),
                child:
                    Icon(LucideIcons.flame, color: AppTheme.accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$pts points',
                        style: TextStyle(
                            color: AppTheme.accentText,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    Text('$eventName · $sport',
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  // ── Coach details ──────────────────────────────────────────────────────
  Widget _buildCoachInfoSection(Map<String, dynamic> data) {
    final level = data['coachingLevel'] as String? ?? '—';
    final years = data['yearsOfExperience'] as String? ?? '—';
    final org = data['teamOrganization'] as String? ?? '—';
    final sports = (data['primarySports'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '—';
    final certs = data['certifications'] as String? ?? '';
    final bio = data['coachingBio'] as String? ?? '';
    final bgy = data['barangay'] as String? ?? '—';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Coaching Info'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          _infoRow(
              icon: LucideIcons.medal,
              iconBg: AppTheme.accentSurface,
              iconColor: AppTheme.accent,
              label: 'Coaching Level',
              value: level,
              valueColor: AppTheme.accentText),
          _infoRow(
              icon: LucideIcons.clock,
              iconBg: AppTheme.cardNested,
              label: 'Experience',
              value: years),
          _infoRow(
              icon: LucideIcons.building,
              iconBg: AppTheme.cardNested,
              label: 'Team / Organization',
              value: org),
          _infoRow(
              icon: LucideIcons.volleyball,
              iconBg: AppTheme.accentSurface,
              iconColor: AppTheme.accent,
              label: 'Sport',
              value: sports),
          _infoRow(
              icon: LucideIcons.mapPin,
              iconBg: AppTheme.cardNested,
              label: 'Barangay',
              value: bgy),
          if (certs.isNotEmpty)
            _infoRow(
                icon: LucideIcons.trophy,
                iconBg: AppTheme.cardNested,
                label: 'Certifications',
                value: certs),
          if (bio.isNotEmpty) _bioRow(bio),
          if (bio.isEmpty && certs.isEmpty)
            _infoRow(
                icon: LucideIcons.fileText,
                iconBg: AppTheme.cardNested,
                label: 'Bio',
                value: 'Not set',
                isLast: true),
        ]),
      ),
    ]);
  }

  // ── Organizer details ──────────────────────────────────────────────────
  Widget _buildOrganizerInfoSection(Map<String, dynamic> data) {
    final org = data['organization'] as String? ?? '—';
    final orgType = data['organizationType'] as String? ?? '—';
    final sports = (data['sportsOrganized'] as List?)
            ?.map((e) => e.toString())
            .join(', ') ??
        '—';
    final certs = data['certifications'] as String? ?? '';
    final bio = data['bio'] as String? ?? '';
    final bgy = data['barangay'] as String? ?? '—';
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
            decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              _infoRow(
                  icon: LucideIcons.building,
                  iconBg: AppTheme.accentSurface,
                  iconColor: AppTheme.accent,
                  label: 'Organization',
                  value: org,
                  valueColor: AppTheme.accentText),
              _infoRow(
                  icon: LucideIcons.tag,
                  iconBg: AppTheme.cardNested,
                  label: 'Type',
                  value: orgType),
              _infoRow(
                  icon: LucideIcons.calendar,
                  iconBg: AppTheme.accentSurface,
                  iconColor: AppTheme.accent,
                  label: 'Events Created',
                  value: '$eventCount events',
                  valueColor: AppTheme.accentText),
              _infoRow(
                  icon: LucideIcons.volleyball,
                  iconBg: AppTheme.cardNested,
                  label: 'Sports Organized',
                  value: sports),
              _infoRow(
                  icon: LucideIcons.mapPin,
                  iconBg: AppTheme.cardNested,
                  label: 'Barangay',
                  value: bgy),
              if (certs.isNotEmpty)
                _infoRow(
                    icon: LucideIcons.trophy,
                    iconBg: AppTheme.cardNested,
                    label: 'Certifications',
                    value: certs),
              if (bio.isNotEmpty)
                _bioRow(bio)
              else
                _infoRow(
                    icon: LucideIcons.fileText,
                    iconBg: AppTheme.cardNested,
                    label: 'Bio',
                    value: 'Not set',
                    isLast: true),
            ]),
          ),
        ]);
      },
    );
  }

  // ── App settings (Dark Mode) ───────────────────────────────────────────
  Widget _buildSettingsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Settings'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          Obx(() {
            final isDark = ThemeController.to.isDark.value;
            return _settingsRow(
              icon: isDark ? LucideIcons.sun : LucideIcons.moon,
              label: 'Dark Mode',
              trailing: Switch(
                value: isDark,
                onChanged: (_) => ThemeController.to.toggleTheme(),
                activeColor: AppTheme.accent,
                inactiveThumbColor: AppTheme.muted,
                inactiveTrackColor: AppTheme.border,
              ),
            );
          }),
          // Play requires the privacy policy to be reachable from inside the
          // app, not only from the store listing.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openPrivacyPolicy,
            child: _settingsRow(
              icon: LucideIcons.shieldCheck,
              label: 'Privacy Policy',
              sub: 'What we collect, and how to delete it',
              trailing: Icon(LucideIcons.externalLink,
                  color: AppTheme.muted, size: 16),
              isLast: true,
            ),
          ),
        ]),
      ),
    ]);
  }

  // ── Sign out ───────────────────────────────────────────────────────────
  Widget _buildSignOutSection(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.errorSurface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppTheme.errorText.withValues(alpha: 0.4))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppTheme.errorSurfaceStrong,
                borderRadius: BorderRadius.circular(10)),
            child:
                Icon(LucideIcons.logOut, color: AppTheme.errorText, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign Out',
                    style: TextStyle(
                        color: AppTheme.errorText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                Text('Return to login screen',
                    style: TextStyle(color: AppTheme.sub, fontSize: 11)),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: AppTheme.errorText, size: 20),
        ]),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final opened = await AppLinks.open(AppLinks.privacyPolicy);
    if (!opened) {
      Get.snackbar(
        'Could not open the link',
        'Visit ${AppLinks.privacyPolicy} in your browser.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.card,
        colorText: AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 5),
      );
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────
  // Deliberately understated next to Sign Out: Google Play requires this to
  // be reachable in-app, but it is permanent, so it should not compete for
  // attention with the action almost everyone actually wants.
  Widget _buildDeleteAccountRow() {
    return Center(
      child: TextButton(
        onPressed: () => Get.toNamed('/account/delete'),
        child: Text('Delete my account',
            style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: AppTheme.muted)),
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Icon(LucideIcons.logOut, color: AppTheme.textPrimary, size: 32),
          const SizedBox(height: 12),
          Text('Sign Out?',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('You will be returned to the login screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.sub, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                    onPressed: () => Get.back(),
                    child: Text('Cancel',
                        style: TextStyle(
                            color: AppTheme.sub,
                            fontWeight: FontWeight.w600))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 50,
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
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Shared row builders ────────────────────────────────────────────────
  Widget _infoRow({
    required IconData icon,
    required Color iconBg,
    Color? iconColor,
    required String label,
    required String value,
    Color? valueColor,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: iconColor ?? AppTheme.sub, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: valueColor ?? AppTheme.sub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }

  Widget _bioRow(String bio) {
    return Container(
      decoration:
          BoxDecoration(border: Border(top: BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bio',
              style: TextStyle(
                  color: AppTheme.sub,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(bio,
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13, height: 1.5)),
        ]),
      ),
    );
  }

  Widget _settingsRow({
    required IconData icon,
    required String label,
    String? sub,
    required Widget trailing,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
          border: Border(
              bottom: isLast
                  ? BorderSide.none
                  : BorderSide(color: AppTheme.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppTheme.cardNested,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppTheme.sub, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                if (sub != null)
                  Text(sub,
                      style: TextStyle(color: AppTheme.muted, fontSize: 10)),
              ],
            ),
          ),
          trailing,
        ]),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              color: AppTheme.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1)),
    );
  }
}
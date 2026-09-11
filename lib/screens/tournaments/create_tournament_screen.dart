// lib/screens/tournaments/create_tournament_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../models/tournament.dart';
import '../../models/venue.dart';
import '../../services/tournament_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/bracket.dart';
import '../../utils/error_messages.dart';
import '../events/venue_map_picker_screen.dart';
import '../profile/edit_profile_screen.dart';

const _kRadius = 14.0;

/// Lets an approved organizer draw a single-elimination bracket: name it,
/// pick the sport and venue, then enter the coach teams that will play.
///
/// Deliberately one scrolling form rather than a multi-step wizard — there
/// is far less to fill in here than when creating an event, because every
/// matchup's roster comes from the teams themselves.
///
/// The order teams are added is the seed order, and seeding is what decides
/// who gets a bye when the field isn't a power of two, so the list can be
/// reordered before the bracket is drawn. After that it is fixed.
class CreateTournamentScreen extends StatefulWidget {
  const CreateTournamentScreen({super.key});
  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Gated on the same two things as event creation: admin approval, and
  // having declared at least one sport to organize.
  List<String> _allowedSports = [];
  bool _isApprovedOrganizer = false;
  bool _loadingAllowedSports = true;

  String _sport = '';
  Venue? _venue;
  bool _isPublic = true;
  bool _isSaving = false;

  /// Entrants in seed order — index 0 is the top seed.
  final List<TournamentEntrant> _entrants = [];

  @override
  void initState() {
    super.initState();
    _loadAllowedSports();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllowedSports() async {
    setState(() => _loadingAllowedSports = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final sports = (data['sportsOrganized'] as List?)?.cast<String>() ?? [];
    if (!mounted) return;
    setState(() {
      _allowedSports = sports;
      if (sports.length == 1) _sport = sports.first;
      _isApprovedOrganizer = data['organizerStatus'] == 'approved';
      _loadingAllowedSports = false;
    });
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.accentSurface,
      colorText: isError ? AppTheme.error : AppTheme.accentText,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ── Entrants ─────────────────────────────────────────

  /// Lists every coach who coaches this sport, minus the ones already
  /// entered — the same team twice would put a side against itself.
  void _pickTeamSheet() {
    final future = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'coach')
        .where('primarySports', arrayContains: _sport)
        .get();
    final search = TextEditingController();
    final taken = _entrants.map((e) => e.coachId).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => FutureBuilder<QuerySnapshot>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 240,
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.accent, strokeWidth: 2)));
          }
          final allTeams = (snapshot.data?.docs ?? [])
              .map((d) => {...d.data() as Map<String, dynamic>, 'uid': d.id})
              .where((c) => !taken.contains(c['uid'] as String))
              .toList();

          return StatefulBuilder(
            builder: (ctx, setModal) {
              final query = search.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? allTeams
                  : allTeams.where((c) {
                      final teamName =
                          (c['teamOrganization'] as String? ?? '').toLowerCase();
                      final coachName =
                          (c['fullName'] as String? ?? '').toLowerCase();
                      return teamName.contains(query) ||
                          coachName.contains(query);
                    }).toList();

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.7,
                maxChildSize: 0.92,
                builder: (_, ctrl) => Column(children: [
                  const SizedBox(height: 12),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text('Add a team',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: search,
                      autofocus: true,
                      style: TextStyle(color: AppTheme.textPrimary),
                      onChanged: (_) => setModal(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search team or coach name...',
                        hintStyle: TextStyle(color: AppTheme.muted),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AppTheme.muted, size: 20),
                        filled: true,
                        fillColor: AppTheme.bg,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                taken.isEmpty
                                    ? 'No $_sport teams found'
                                    : 'No other $_sport teams left to add',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.muted, fontSize: 13)),
                          ))
                        : ListView.builder(
                            controller: ctrl,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final logoUrl = c['teamLogoUrl'] as String?;
                              final teamName = c['teamOrganization'] as String? ??
                                  'Unnamed Team';
                              return ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                      color: AppTheme.cardNested,
                                      borderRadius: BorderRadius.circular(10),
                                      border:
                                          Border.all(color: AppTheme.border)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: logoUrl != null && logoUrl.isNotEmpty
                                        ? Image.network(logoUrl,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder: (_, __, ___) => Icon(
                                                Icons.shield_outlined,
                                                color: AppTheme.muted,
                                                size: 20))
                                        : Icon(Icons.shield_outlined,
                                            color: AppTheme.muted, size: 20),
                                  ),
                                ),
                                title: Text(teamName,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: Text(c['fullName'] as String? ?? '',
                                    style: TextStyle(
                                        color: AppTheme.sub, fontSize: 11)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _addEntrant(
                                    coachId: c['uid'] as String,
                                    teamName: teamName,
                                    coachName: c['fullName'] as String? ?? '',
                                    logoUrl: logoUrl,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addEntrant({
    required String coachId,
    required String teamName,
    required String coachName,
    String? logoUrl,
  }) async {
    try {
      final entrant = await TournamentService.buildEntrant(
        seed: _entrants.length + 1,
        coachId: coachId,
        teamName: teamName,
        coachName: coachName,
        teamLogoUrl: logoUrl,
      );
      if (mounted) setState(() => _entrants.add(entrant));
    } on EmptyEntrantRosterException catch (e) {
      // A team with nobody on it could never finish its matchup, so it is
      // refused at the door rather than deadlocking the bracket later.
      if (mounted) _snack('Empty Roster', e.toString(), isError: true);
    } catch (e) {
      if (mounted) _snack('Error', friendlyError(e), isError: true);
    }
  }

  void _moveEntrant(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _entrants.length) return;
    setState(() {
      final moved = _entrants.removeAt(index);
      _entrants.insert(target, moved);
    });
  }

  // ── Create ───────────────────────────────────────────

  Future<void> _onCreate() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sport.isEmpty) {
      _snack('Select Sport', 'Please select a sport.');
      return;
    }
    if (_venue == null) {
      _snack('Select Venue', 'Please set where the tournament will be played.');
      return;
    }
    if (_entrants.length < Tournament.minEntrants) {
      _snack('Not Enough Teams',
          'A bracket needs at least ${Tournament.minEntrants} teams. '
          'For a single game, create an event instead.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final id = await TournamentService.create(
        organizerId: uid,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        sport: _sport,
        isPublic: _isPublic,
        venue: _venue!.name,
        venueAddress: _venue!.address,
        venueLat: _venue!.lat,
        venueLng: _venue!.lng,
        venueType: _venue!.type,
        entrants: _entrants,
      );
      if (!mounted) return;
      // Replace this screen with the bracket: there is nothing to come back
      // to a half-filled create form for.
      Get.offNamed('/tournaments/detail', arguments: {'tournamentId': id});
      _snack('Bracket Drawn! 🏆', 'Schedule the first round to get started.');
    } catch (e) {
      if (mounted) _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingAllowedSports) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: const Center(
            child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2)),
      );
    }
    if (!_isApprovedOrganizer) {
      return _blockingScreen(
        icon: Icons.hourglass_top_rounded,
        title: "Your organizer account isn't currently approved",
        subtitle: 'Contact the app admin for details. You may just need to '
            'wait for review, or your account may need another look.',
      );
    }
    if (_allowedSports.isEmpty) {
      return _blockingScreen(
        icon: Icons.sports_outlined,
        title: "You haven't set which sports you organize yet",
        subtitle:
            'Add at least one sport in your profile before creating a tournament.',
        showUpdateSportsButton: true,
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
              Text('New Tournament',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _label('Tournament Name'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _nameCtrl,
                    hint: 'e.g. Barangay Cup 2026',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Give the tournament a name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Description (optional)'),
                  const SizedBox(height: 8),
                  _field(
                      controller: _descCtrl,
                      hint: 'A short note about the competition',
                      maxLines: 2),
                  const SizedBox(height: 20),
                  _label('Sport'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _allowedSports
                        .map((s) => _chip(
                              label: s,
                              selected: _sport == s,
                              onTap: () => setState(() {
                                if (_sport == s) return;
                                _sport = s;
                                // Entrants are coaches of the old sport, so
                                // they can't carry over to a new one.
                                _entrants.clear();
                              }),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 20),
                  _label('Venue'),
                  const SizedBox(height: 8),
                  _venueTile(),
                  const SizedBox(height: 24),
                  _teamsSection(),
                  const SizedBox(height: 20),
                  _publicToggle(),
                  const SizedBox(height: 28),
                  _isSaving
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.accent, strokeWidth: 2.5))
                      : SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _onCreate,
                            child: const Text('Draw the Bracket'),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Pieces ───────────────────────────────────────────

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted, fontSize: 13),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius),
            borderSide: const BorderSide(color: AppTheme.accent)),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: selected ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? AppTheme.accent : AppTheme.border)),
        child: Text(label,
            style: TextStyle(
                color: selected ? AppTheme.accentText : AppTheme.sub,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _venueTile() {
    return GestureDetector(
      onTap: () async {
        final picked = await Navigator.push<Venue>(
          context,
          MaterialPageRoute(builder: (_) => const VenueMapPickerScreen()),
        );
        if (picked != null && mounted) setState(() => _venue = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          const Icon(Icons.place_outlined, color: AppTheme.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: _venue == null
                ? Text('Drop a pin where it will be played',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_venue!.name,
                          style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(_venue!.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: AppTheme.sub, fontSize: 11)),
                    ],
                  ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppTheme.muted, size: 20),
        ]),
      ),
    );
  }

  Widget _teamsSection() {
    final count = _entrants.length;
    final canAdd = count < Tournament.maxEntrants;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _label('Teams'),
        const Spacer(),
        Text('$count of ${Tournament.maxEntrants}',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      Text(
          'Listed in seed order — the top seed is first. Seeding decides who '
          'gets a bye, so reorder before drawing the bracket.',
          style: TextStyle(color: AppTheme.muted, fontSize: 11)),
      const SizedBox(height: 10),
      if (_sport.isEmpty)
        _hintBox('Pick a sport first to see the teams that can enter.')
      else ...[
        ..._entrants.asMap().entries.map((e) => _entrantRow(e.key, e.value)),
        if (count > 0) const SizedBox(height: 8),
        if (canAdd)
          GestureDetector(
            onTap: _pickTeamSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(color: AppTheme.border)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: AppTheme.accent, size: 18),
                    SizedBox(width: 6),
                    Text('Add a team',
                        style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
            ),
          ),
        if (count >= Tournament.minEntrants) ...[
          const SizedBox(height: 10),
          _bracketPreview(count),
        ],
      ],
    ]);
  }

  Widget _entrantRow(int index, TournamentEntrant entrant) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent)),
            child: Center(
                child: Text('${index + 1}',
                    style: TextStyle(
                        color: AppTheme.accentText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entrant.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${entrant.coachName} · ${entrant.players.length} players',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppTheme.sub, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: index == 0 ? null : () => _moveEntrant(index, -1),
            icon: Icon(Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: index == 0 ? AppTheme.border : AppTheme.sub),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: index == _entrants.length - 1
                ? null
                : () => _moveEntrant(index, 1),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: index == _entrants.length - 1
                    ? AppTheme.border
                    : AppTheme.sub),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _entrants.removeAt(index)),
            icon: Icon(Icons.close_rounded, size: 18, color: AppTheme.muted),
          ),
        ]),
      ),
    );
  }

  /// Says up front what the field will look like, so the organizer isn't
  /// surprised that adding a sixth team hands two teams a free pass.
  Widget _bracketPreview(int count) {
    final rounds = roundCountFor(count);
    final byes = nextPowerOfTwo(count) - count;
    final opener = roundLabel(1, rounds);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        const Icon(Icons.account_tree_outlined,
            color: AppTheme.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$count teams · $rounds rounds · starts at the $opener\n'
            '${count - 1} matches to play'
            '${byes == 0 ? '' : ' · top $byes ${byes == 1 ? 'seed gets a bye' : 'seeds get byes'}'}',
            style: TextStyle(color: AppTheme.sub, fontSize: 11, height: 1.5),
          ),
        ),
      ]),
    );
  }

  Widget _hintBox(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: AppTheme.border)),
        child: Text(text,
            style: TextStyle(color: AppTheme.muted, fontSize: 12)),
      );

  Widget _publicToggle() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Public tournament',
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Its matches show on the venue map',
                  style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: _isPublic,
          onChanged: (v) => setState(() => _isPublic = v),
          activeThumbColor: AppTheme.accent,
          inactiveThumbColor: AppTheme.muted,
          inactiveTrackColor: AppTheme.border,
        ),
      ]),
    );
  }

  Widget _blockingScreen({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showUpdateSportsButton = false,
  }) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.muted, size: 44),
              const SizedBox(height: 16),
              Text(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.sub, fontSize: 13)),
              const SizedBox(height: 24),
              if (showUpdateSportsButton)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Get.to(() => const EditProfileScreen())
                        ?.then((_) => _loadAllowedSports()),
                    child: const Text('Update My Sports'),
                  ),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Go Back',
                    style: TextStyle(color: AppTheme.sub, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

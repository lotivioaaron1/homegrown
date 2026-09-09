// lib/screens/events/create_event_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../constants/maps_config.dart';
import '../../theme/app_theme.dart';
import '../../models/venue.dart';
import '../../services/notification_service.dart';
import '../../services/places_service.dart';
import '../../services/team_service.dart';
import '../../widgets/player_avatar.dart';
import '../profile/edit_profile_screen.dart';
import 'venue_map_picker_screen.dart';
import '../../utils/error_messages.dart';

const _kRadius   = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);
const List<String> _kEventTypes = ['Tournament', 'Friendly', 'League'];

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});
  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int  _step = 0; bool _isLoading = false;
  final _step1Key = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();

  // ── Venue — live search + manual pin ──────
  Venue? _selectedVenue;

  String _sport = ''; String _eventType = '';
  DateTime? _eventDate; TimeOfDay? _eventTime;
  final List<Map<String, dynamic>> _addedPlayers = [];
  bool _isPublic = true; bool _isDraft = false;

  // ── Team pick ──────────────────────────────
  // Which coach's roster (if any) auto-filled each side, so re-picking a
  // team only replaces that side's auto-added players. Team identity
  // (name/coach/logo) is derived entirely from the picked coach, not typed
  // by the organizer — see _selectTeam.
  String? _teamACoachId;
  String? _teamBCoachId;
  String _teamAName = 'Team A'; String _teamBName = 'Team B';
  String? _teamACoachName; String? _teamBCoachName;
  String? _teamALogoUrl; String? _teamBLogoUrl;
  bool _expandedA = false; bool _expandedB = false;

  // ── Sport restricted to what this organizer declared, and gated on
  // admin approval (see firestore.rules / admin_review_screen.dart) ──
  List<String> _allowedSports = [];
  bool _isApprovedOrganizer = false;
  bool _loadingAllowedSports = true;

  @override
  void initState() {
    super.initState();
    _loadAllowedSports();
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
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: AppTheme.muted, size: 40),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.sub, fontSize: 13)),
            const SizedBox(height: 24),
            if (showUpdateSportsButton) ...[
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Get.to(() => const EditProfileScreen())
                      ?.then((_) => _loadAllowedSports()),
                  child: const Text('Update My Sports'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Back', style: TextStyle(color: AppTheme.sub)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _loadAllowedSports() async {
    setState(() => _loadingAllowedSports = true);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final sports = (data['sportsOrganized'] as List?)?.cast<String>() ?? [];
    if (mounted) {
      setState(() {
        _allowedSports = sports;
        // A single-sport organizer has nothing to choose between, so the one
        // chip is preselected rather than made a required tap. Multi-sport
        // organizers (an SK Liga running both a basketball and a volleyball
        // tournament) still pick deliberately.
        if (sports.length == 1) _sport = sports.first;
        _isApprovedOrganizer = data['organizerStatus'] == 'approved';
        _loadingAllowedSports = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  // ── Venue picker bottom sheet ─────────────

  void _pickVenue() {
    final search = TextEditingController();
    List<Venue> results = [];
    bool isSearching = false;
    bool hasSearched = false;
    bool searchFailed = false;
    bool sheetOpen = true;
    Timer? debounce;
    // Guards against a slow response for an older query overwriting
    // the results of a newer one the user has since typed.
    int searchToken = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) {
          Future<void> runSearch(String q) async {
            if (!sheetOpen) return;
            searchToken++;
            final token = searchToken;
            // A one- or two-character query matches half of Legazpi and still
            // bills a full Text Search, so it's treated exactly like an empty
            // box: reset to the prompt, send nothing.
            if (q.trim().length < PlacesService.minQueryLength) {
              // Bumping the token above already discarded any in-flight
              // response, so this has to clear the spinner itself.
              if (ctx.mounted) {
                setModal(() {
                  results = []; hasSearched = false;
                  searchFailed = false; isSearching = false;
                });
              }
              return;
            }
            // Built without --dart-define-from-file=dart_defines.json, so the
            // key is empty and Google would answer REQUEST_DENIED. Saying so
            // is the whole point of this guard: the generic failure path below
            // reads as "Google is down" and sends people hunting the wrong
            // problem for hours.
            if (!MapsConfig.isConfigured) {
              if (ctx.mounted) {
                setModal(() {
                  results = []; isSearching = false;
                  hasSearched = true; searchFailed = true;
                });
              }
              _snack('Search Unavailable', MapsConfig.missingKeyMessage,
                  isError: true);
              return;
            }
            if (ctx.mounted) {
              setModal(() { isSearching = true; searchFailed = false; });
            }
            try {
              final found = await PlacesService.searchVenues(q);
              if (!sheetOpen || !ctx.mounted || token != searchToken) return;
              setModal(() {
                results = found; isSearching = false;
                hasSearched = true; searchFailed = false;
              });
            } catch (e) {
              if (!sheetOpen || !ctx.mounted || token != searchToken) return;
              setModal(() {
                results = []; isSearching = false;
                hasSearched = true; searchFailed = true;
              });
              _snack(
                'Search Error',
                e is PlacesException
                    ? e.message
                    : 'Could not search venues. Check internet connection.',
                isError: true);
            }
          }

          // The single entry point for starting a search. Everything that can
          // trigger one goes through here so nothing bypasses the debounce —
          // the retry button used to call runSearch directly, turning a held
          // tap into one billable request per tap.
          void scheduleSearch(String q) {
            debounce?.cancel();
            debounce =
                Timer(const Duration(milliseconds: 400), () => runSearch(q));
          }

          Future<void> openMapPicker() async {
            final picked = await Navigator.push<Venue>(ctx,
                MaterialPageRoute(builder: (_) => const VenueMapPickerScreen()));
            if (picked != null) {
              setState(() => _selectedVenue = picked);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          }

          // Always reachable — Places often returns plausible-but-wrong
          // matches, so the manual pin can't be gated on zero results.
          Widget dropPinButton() => TextButton.icon(
            onPressed: openMapPicker,
            icon: const Icon(Icons.add_location_alt_rounded,
                color: AppTheme.accent),
            label: const Text("Can't find it? Drop a pin",
                style: TextStyle(color: AppTheme.accent)),
          );

          Widget buildResults(ScrollController ctrl) {
            if (isSearching) {
              return const Center(child: CircularProgressIndicator(
                  color: AppTheme.accent, strokeWidth: 2));
            }
            if (!hasSearched) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'Type at least ${PlacesService.minQueryLength} letters to search',
                      style: TextStyle(
                          color: AppTheme.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  dropPinButton(),
                ],
              ));
            }
            if (searchFailed) {
              return Center(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      color: AppTheme.muted, size: 32),
                  const SizedBox(height: 10),
                  Text('Search is unavailable right now', textAlign: TextAlign.center,
                      style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('You can still add the venue by dropping a pin on the map.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity, height: 46,
                    child: ElevatedButton.icon(
                      onPressed: openMapPicker,
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Drop a Pin'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => scheduleSearch(search.text),
                    child: const Text('Retry search',
                        style: TextStyle(color: AppTheme.accent)),
                  ),
                ],
              )));
            }
            if (results.isEmpty) {
              return Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No venues found', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  dropPinButton(),
                ],
              ));
            }
            return Column(children: [
              Expanded(child: _buildVenueList(ctrl, results, ctx)),
              Divider(color: AppTheme.border, height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: dropPinButton()),
            ]);
          }

          return DraggableScrollableSheet(
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
                child: Text('Select Venue', style: TextStyle(
                    color: AppTheme.textPrimary, fontSize: 16,
                    fontWeight: FontWeight.w800)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: search,
                  autofocus: true,
                  style: TextStyle(color: AppTheme.textPrimary),
                  onChanged: scheduleSearch,
                  decoration: InputDecoration(
                    hintText: 'Search venue...',
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
                        borderSide: const BorderSide(
                            color: AppTheme.accent, width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: buildResults(ctrl)),
            ]),
          );
        },
      ),
    ).whenComplete(() {
      sheetOpen = false;
      debounce?.cancel();
    });
  }

  Widget _buildVenueList(
      ScrollController ctrl, List<Venue> results, BuildContext sheetCtx) {
    return ListView.builder(
      controller: ctrl,
      itemCount: results.length,
      itemBuilder: (_, i) {
        final v = results[i];
        final sel = v.name == _selectedVenue?.name;
        return ListTile(
          dense: true,
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: sel
                  ? AppTheme.accentSurface : AppTheme.cardNested,
              borderRadius: BorderRadius.circular(8),
              border: sel
                  ? Border.all(color: AppTheme.accent) : null),
            child: Icon(Icons.location_on_rounded,
                color: sel ? AppTheme.accent : AppTheme.muted,
                size: 18)),
          title: Text(v.name, style: TextStyle(
            color: sel ? AppTheme.accentText : AppTheme.textPrimary,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13)),
          subtitle: Text(v.address, style: TextStyle(
              color: AppTheme.muted, fontSize: 11)),
          trailing: sel
              ? const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accent, size: 20) : null,
          onTap: () {
            setState(() => _selectedVenue = v);
            Navigator.pop(sheetCtx);
          },
        );
      },
    );
  }

  // ── Navigation ────────────────────────────

  void _nextStep() {
    if (_step == 0) {
      if (!_step1Key.currentState!.validate()) return;
      if (_sport.isEmpty) { _snack('Select Sport', 'Please select a sport.'); return; }
      if (_eventType.isEmpty) { _snack('Event Type', 'Please select an event type.'); return; }
      if (_eventDate == null) { _snack('Select Date', 'Please select a date.'); return; }
      if (_selectedVenue == null) { _snack('Select Venue', 'Please select a venue.'); return; }
    }
    if (_step == 1 && _addedPlayers.isEmpty) {
      _snack('No Players', 'Pick at least one team with players.'); return;
    }
    setState(() => _step++);
  }

  void _prevStep() { if (_step > 0) setState(() => _step--); }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(
          primary: AppTheme.accent, onPrimary: AppTheme.buttonFg,
          surface: AppTheme.card, onSurface: AppTheme.textPrimary)),
        child: child!),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context, initialTime: _eventTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.dark(
          primary: AppTheme.accent, onPrimary: AppTheme.buttonFg,
          surface: AppTheme.card, onSurface: AppTheme.textPrimary)),
        child: child!),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  void _removePlayer(String uid) =>
      setState(() => _addedPlayers.removeWhere((p) => p['uid'] == uid));

  /// Switching sport invalidates whatever teams are already picked: the
  /// picker only ever lists coaches for the sport selected at the time, so
  /// carrying the old picks over would publish (say) a volleyball event
  /// rostered with basketball players. Only a multi-sport organizer — an SK
  /// Liga running both tournaments — can reach this; a single-sport organizer
  /// has one chip, already selected.
  ///
  /// Clearing silently would lose a roster the organizer spent real time on,
  /// so it's confirmed first — but only when there's something to lose.
  Future<void> _changeSport(String sport) async {
    if (sport == _sport) return;

    final hasPicks = _teamACoachId != null ||
        _teamBCoachId != null ||
        _addedPlayers.isNotEmpty;
    if (!hasPicks) {
      setState(() => _sport = sport);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.border)),
        title: Text('Switch to $sport?',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800)),
        content: Text(
            "This clears the teams and players you've picked, because each "
            'team belongs to the sport its coach handles.',
            style: TextStyle(color: AppTheme.sub, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch Sport',
                style: TextStyle(color: AppTheme.accent,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _sport = sport;
      _teamACoachId   = null;      _teamBCoachId   = null;
      _teamAName      = 'Team A';  _teamBName      = 'Team B';
      _teamACoachName = null;      _teamBCoachName = null;
      _teamALogoUrl   = null;      _teamBLogoUrl   = null;
      _expandedA      = false;     _expandedB      = false;
      _addedPlayers.clear();
    });
  }

  // ── Pick a coach's team to auto-fill a side ─

  void _pickTeamSheet(String side) {
    final future = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'coach')
        .where('primarySports', arrayContains: _sport)
        .get();
    final search = TextEditingController();

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
                child: Center(child: CircularProgressIndicator(
                    color: AppTheme.accent, strokeWidth: 2)));
          }
          final allTeams = (snapshot.data?.docs ?? [])
              .map((d) => {...d.data() as Map<String, dynamic>, 'uid': d.id})
              .toList();

          return StatefulBuilder(
            builder: (ctx, setModal) {
              final query = search.text.trim().toLowerCase();
              final filtered = query.isEmpty
                  ? allTeams
                  : allTeams.where((c) {
                      final teamName =
                          (c['teamOrganization'] as String? ?? '').toLowerCase();
                      final coachName = (c['fullName'] as String? ?? '').toLowerCase();
                      return teamName.contains(query) || coachName.contains(query);
                    }).toList();

              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.7,
                maxChildSize: 0.92,
                builder: (_, ctrl) => Column(children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text('Pick Team $side', style: TextStyle(
                        color: AppTheme.textPrimary, fontSize: 16,
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
                        filled: true, fillColor: AppTheme.bg,
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
                        ? Center(child: Text('No $_sport teams found',
                            style: TextStyle(color: AppTheme.muted, fontSize: 13)))
                        : ListView.builder(
                            controller: ctrl,
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final c = filtered[i];
                              final logoUrl = c['teamLogoUrl'] as String?;
                              final teamName =
                                  c['teamOrganization'] as String? ?? 'Unnamed Team';
                              return ListTile(
                                leading: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                      color: AppTheme.cardNested,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.border)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: logoUrl != null && logoUrl.isNotEmpty
                                        ? Image.network(logoUrl, fit: BoxFit.cover,
                                            width: 40, height: 40,
                                            errorBuilder: (_, __, ___) => Icon(
                                                Icons.shield_outlined,
                                                color: AppTheme.muted, size: 20))
                                        : Icon(Icons.shield_outlined,
                                            color: AppTheme.muted, size: 20),
                                  ),
                                ),
                                title: Text(teamName, style: TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                                subtitle: Text(c['fullName'] as String? ?? '',
                                    style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                                onTap: () {
                                  Navigator.pop(context);
                                  _selectTeam(side, c['uid'] as String, teamName,
                                      c['fullName'] as String? ?? '', logoUrl);
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

  Future<void> _selectTeam(String side, String coachId, String teamName,
      String coachName, String? logoUrl) async {
    setState(() {
      if (side == 'A') {
        _teamACoachId = coachId;
        _teamAName = teamName;
        _teamACoachName = coachName;
        _teamALogoUrl = logoUrl;
      } else {
        _teamBCoachId = coachId;
        _teamBName = teamName;
        _teamBCoachName = coachName;
        _teamBLogoUrl = logoUrl;
      }
      _addedPlayers.removeWhere((p) => p['source'] == 'team$side');
    });
    try {
      final rosterSnap = await TeamService.fetchRoster(coachId);
      final athleteIds = rosterSnap.docs
          .map((d) => (d.data() as Map<String, dynamic>)['athleteId'] as String)
          .toList();
      if (athleteIds.isEmpty) {
        if (mounted) {
          _snack('Empty Roster', '$teamName has no accepted players yet.');
        }
        return;
      }
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: athleteIds)
          .get();
      final existingUids = _addedPlayers.map((p) => p['uid']).toSet();
      final newPlayers = usersSnap.docs
          .where((d) => !existingUids.contains(d.id))
          .map((d) {
        final u = d.data();
        return {
          'uid': d.id,
          'fullName': u['fullName'] as String? ?? '',
          'position': u['position'] as String? ?? '',
          // Kept for the roster rows below only. It is deliberately *not*
          // written into the event's `players[]` on publish: every screen that
          // renders a saved roster reads the live user doc instead, so a copy
          // frozen here would only go stale.
          'photoUrl': u['photoUrl'] as String? ?? '',
          'team': side,
          'source': 'team$side',
        };
      }).toList();
      if (mounted) setState(() => _addedPlayers.addAll(newPlayers));
    } catch (e) {
      if (mounted) _snack('Error', friendlyError(e), isError: true);
    }
  }

  /// One side's team: an unpicked placeholder that opens the picker, or —
  /// once picked — a card showing the team's logo, name, head coach, and
  /// player count, that expands in place to show the actual roster so the
  /// organizer can review (and lightly trim) who's really playing, instead
  /// of just trusting a bare count.
  Widget _teamCard(String side) {
    final coachId = side == 'A' ? _teamACoachId : _teamBCoachId;
    if (coachId == null) {
      return GestureDetector(
        onTap: () => _pickTeamSheet(side),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: AppTheme.border, width: 1.5)),
          child: Row(children: [
            Icon(Icons.shield_outlined, color: AppTheme.muted, size: 20),
            const SizedBox(width: 10),
            Text('Pick Team $side', style: TextStyle(
                color: AppTheme.muted, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    final teamName  = side == 'A' ? _teamAName : _teamBName;
    final coachName = side == 'A' ? _teamACoachName : _teamBCoachName;
    final logoUrl   = side == 'A' ? _teamALogoUrl : _teamBLogoUrl;
    final expanded  = side == 'A' ? _expandedA : _expandedB;
    final players   = _addedPlayers.where((p) => p['source'] == 'team$side').toList();

    return Container(
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: AppTheme.accent, width: 1.5)),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() {
            if (side == 'A') { _expandedA = !_expandedA; }
            else { _expandedB = !_expandedB; }
          }),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.cardNested,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: logoUrl != null && logoUrl.isNotEmpty
                      ? Image.network(logoUrl, fit: BoxFit.cover,
                          width: 44, height: 44,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.shield_outlined, color: AppTheme.muted, size: 22))
                      : Icon(Icons.shield_outlined, color: AppTheme.muted, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(teamName, overflow: TextOverflow.ellipsis, style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
                  if (coachName != null && coachName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Head Coach: $coachName', overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: AppTheme.sub, fontSize: 11)),
                  ],
                  const SizedBox(height: 2),
                  Text('${players.length} player${players.length == 1 ? '' : 's'}',
                      style: const TextStyle(color: AppTheme.accent, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              GestureDetector(
                onTap: () => _pickTeamSheet(side),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text('Change', style: TextStyle(
                      color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              Icon(expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.muted, size: 20),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(color: AppTheme.border, height: 1),
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No accepted players on this roster yet',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12)),
            )
          else
            Column(children: players.asMap().entries.map((e) {
              final isLast = e.key == players.length - 1;
              final p = e.value;
              final position = p['position'] as String? ?? '';
              return Container(
                decoration: BoxDecoration(border: Border(
                    bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border))),
                child: ListTile(
                  dense: true,
                  leading: PlayerAvatar(
                      name: p['fullName'] as String? ?? '',
                      photoUrl: p['photoUrl'] as String?,
                      size: 34, radius: 10, fontSize: 12),
                  title: Text(p['fullName'] as String? ?? '', style: TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: position.isNotEmpty
                      ? Text(position, style: TextStyle(color: AppTheme.sub, fontSize: 11))
                      : null,
                  trailing: GestureDetector(
                    onTap: () => _removePlayer(p['uid'] as String),
                    child: const Icon(Icons.remove_circle_outline,
                        color: _kErrorRed, size: 20),
                  ),
                ),
              );
            }).toList()),
        ],
      ]),
    );
  }

  Future<void> _onPublish({bool draft = false}) async {
    setState(() { _isLoading = true; _isDraft = draft; });
    try {
      final uid     = FirebaseAuth.instance.currentUser!.uid;
      final eventId = const Uuid().v4();
      final dateTime = _eventDate != null
          ? DateTime(_eventDate!.year, _eventDate!.month, _eventDate!.day,
              _eventTime?.hour ?? 0, _eventTime?.minute ?? 0)
          : null;

      final batch = FirebaseFirestore.instance.batch();
      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(eventId);
      batch.set(eventRef, {
        'eventId':     eventId,
        'organizerId': uid,
        'name':        _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'sport':       _sport,
        'eventType':   _eventType,
        // ── Venue with exact coordinates ──────
        'venue':       _selectedVenue!.name,
        'venueAddress': _selectedVenue!.address,
        'venueLat':    _selectedVenue!.lat,
        'venueLng':    _selectedVenue!.lng,
        'venueType':   _selectedVenue!.type,
        // ─────────────────────────────────────
        'eventDate':   dateTime != null ? Timestamp.fromDate(dateTime) : null,
        'teamAName':   _teamAName,
        'teamBName':   _teamBName,
        'players': _addedPlayers.map((p) => {
          'uid': p['uid'], 'fullName': p['fullName'] ?? '',
          'position': p['position'] ?? '',
          'team': p['team'] ?? 'A',
        }).toList(),
        'playerUids':  _addedPlayers.map((p) => p['uid'] as String).toList(),
        'playerCount': _addedPlayers.length,
        'maxPlayers':  null,
        'isPublic':    _isPublic,
        'teamACoachId': _teamACoachId,
        'teamBCoachId': _teamBCoachId,
        'status':      draft ? 'draft' : 'upcoming',
        'createdAt':   FieldValue.serverTimestamp(),
      });

      // NEW: notify each added athlete, but only for a real publish —
      // a draft isn't visible/confirmed yet, so nobody should be
      // notified about it. Same event name/date used in the message
      // as what's shown elsewhere in the app.
      if (!draft) {
        final eventLabel = _eventDate != null
            ? '${_nameCtrl.text.trim()} on ${_formatDate()}'
            : _nameCtrl.text.trim();
        for (final p in _addedPlayers) {
          await NotificationService.create(
            userId: p['uid'] as String,
            type: 'event_added',
            title: "You're in an upcoming game",
            body: 'Added to $eventLabel at ${_selectedVenue!.name}',
            relatedId: eventId,
            writeBatch: batch,
          );
        }
        // Both head coaches too — their team is in the game even though they
        // aren't on the roster. Kept in a separate loop from the players
        // because the wording differs, and deduped so a coach picked for
        // both sides is only notified once.
        final coachTeams = <String, String>{};
        if (_teamACoachId != null && _teamACoachId!.isNotEmpty) {
          coachTeams[_teamACoachId!] = _teamAName;
        }
        if (_teamBCoachId != null && _teamBCoachId!.isNotEmpty) {
          coachTeams[_teamBCoachId!] = _teamBName;
        }
        for (final entry in coachTeams.entries) {
          await NotificationService.create(
            userId: entry.key,
            type: 'event_added',
            title: 'Your team has an upcoming game',
            body: '${entry.value} plays in $eventLabel '
                'at ${_selectedVenue!.name}',
            relatedId: eventId,
            writeBatch: batch,
          );
        }
      }

      await batch.commit();

      if (!mounted) return;
      Get.back();
      Get.snackbar(
        draft ? 'Draft Saved' : 'Event Published! 🏆',
        draft ? 'Saved as draft.'
            : '${_nameCtrl.text.trim()} is now live!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.accentSurface,
        colorText: AppTheme.accentText,
        margin: const EdgeInsets.all(16), borderRadius: 12,
        duration: const Duration(seconds: 3));
    } catch (e) {
      _snack('Error', friendlyError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String title, String msg, {bool isError = false}) {
    Get.snackbar(title, msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? const Color(0xFF2A1A1A) : AppTheme.card,
      colorText: isError ? _kErrorRed : AppTheme.textPrimary,
      margin: const EdgeInsets.all(16), borderRadius: 12,
      duration: const Duration(seconds: 3));
  }

  String _formatDate() => _eventDate == null
      ? 'Select date' : DateFormat('MMM dd, yyyy').format(_eventDate!);

  String _formatTime() {
    if (_eventTime == null) return 'Select time';
    final h = _eventTime!.hourOfPeriod == 0 ? 12 : _eventTime!.hourOfPeriod;
    final m = _eventTime!.minute.toString().padLeft(2, '0');
    return '$h:$m ${_eventTime!.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loadingAllowedSports) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: const Center(child: CircularProgressIndicator(
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
        subtitle: 'Add at least one sport in your profile before creating an event.',
        showUpdateSportsButton: true,
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        Padding(
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
                    color: AppTheme.textPrimary,
                    size: _step > 0 ? 16 : 18)),
            ),
            const SizedBox(width: 12),
            Text('Create Event', style: TextStyle(
              color: AppTheme.textPrimary, fontSize: 17,
              fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AppTheme.accentSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.accent)),
              child: Text('Step ${_step + 1} of 3', style: TextStyle(
                  color: AppTheme.accentText, fontSize: 11,
                  fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: List.generate(3, (i) => Expanded(
            child: Container(height: 4,
              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
              decoration: BoxDecoration(
                color: i <= _step ? AppTheme.accent : AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
            ),
          ))),
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Form(key: _step1Key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _SectionHeader(icon: Icons.event_rounded,
              title: 'Event Info', subtitle: 'Name, sport & type'),
          const SizedBox(height: 16),
          _field(ctrl: _nameCtrl, hint: 'e.g. Barangay Cup 2025',
            icon: Icons.emoji_events_outlined,
            validator: (v) => v!.trim().isEmpty ? 'Event name is required' : null),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl, maxLines: 2, maxLength: 120,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: _deco(hint: 'Description (optional)',
                icon: Icons.description_outlined)
                .copyWith(counterStyle: TextStyle(
                    color: AppTheme.sub, fontSize: 11)),
          ),
          const _SectionLabel(label: 'Sport'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: _allowedSports.map((s) => _Chip(
              label: s, sel: _sport == s,
              onTap: () => _changeSport(s))).toList()),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Event Type'),
          const SizedBox(height: 8),
          Wrap(spacing: 8,
            children: _kEventTypes.map((t) => _Chip(
              label: t, sel: _eventType == t,
              onTap: () => setState(() => _eventType = t))).toList()),
          const SizedBox(height: 16),
          const _SectionHeader(icon: Icons.schedule_rounded,
              title: 'Schedule & Venue', subtitle: 'When and where'),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _dateTile()),
            const SizedBox(width: 10),
            Expanded(child: _timeTile()),
          ]),
          const SizedBox(height: 12),

          // ── Venue picker ──────────────────
          GestureDetector(
            onTap: _pickVenue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(_kRadius),
                border: Border.all(
                  color: _selectedVenue != null
                      ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                  color: _selectedVenue != null
                      ? AppTheme.accent : AppTheme.muted,
                  size: 20),
                const SizedBox(width: 12),
                Expanded(child: _selectedVenue != null
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(_selectedVenue!.name, style: TextStyle(
                          color: AppTheme.textPrimary, fontSize: 14,
                          fontWeight: FontWeight.w600)),
                        Text(_selectedVenue!.type, style: TextStyle(
                            color: AppTheme.muted, fontSize: 11)),
                      ])
                    : Text('Select Venue (Legazpi City)', style: TextStyle(
                        color: AppTheme.muted, fontSize: 14))),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.muted, size: 20),
              ]),
            ),
          ),

          // Venue coordinates badge
          if (_selectedVenue != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent)),
              child: Row(children: [
                const Icon(Icons.gps_fixed_rounded,
                    color: AppTheme.accent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'GPS: ${_selectedVenue!.lat.toStringAsFixed(4)}, '
                  '${_selectedVenue!.lng.toStringAsFixed(4)}',
                  style: TextStyle(color: AppTheme.accentText,
                      fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],

          const SizedBox(height: 32),
          _Btn(label: 'Continue', onTap: _nextStep),
        ]),
      ),
    );
  }

  Widget _dateTile() => GestureDetector(
    onTap: _pickDate,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
            color: _eventDate != null ? AppTheme.accent : AppTheme.border,
            width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date', style: TextStyle(color: AppTheme.sub, fontSize: 11)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.calendar_today_outlined,
            color: _eventDate != null ? AppTheme.accent : AppTheme.muted,
            size: 14),
          const SizedBox(width: 6),
          Flexible(child: Text(_formatDate(), style: TextStyle(
            color: _eventDate != null ? AppTheme.accentText : AppTheme.muted,
            fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    ),
  );

  Widget _timeTile() => GestureDetector(
    onTap: _pickTime,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(
            color: _eventTime != null ? AppTheme.accent : AppTheme.border,
            width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Time', style: TextStyle(color: AppTheme.sub, fontSize: 11)),
        const SizedBox(height: 4),
        Row(children: [
          Icon(Icons.access_time_rounded,
            color: _eventTime != null ? AppTheme.accent : AppTheme.muted,
            size: 14),
          const SizedBox(width: 6),
          Text(_formatTime(), style: TextStyle(
            color: _eventTime != null ? AppTheme.accentText : AppTheme.muted,
            fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ]),
    ),
  );

  // ── Step 2 ────────────────────────────────

  Widget _buildStep2() {
    return Column(children: [
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionHeader(icon: Icons.group_add_rounded,
            title: 'Teams & Players',
            subtitle: '${_nameCtrl.text.trim()} · $_sport'),
          const SizedBox(height: 16),
          const _SectionLabel(label: 'Pick a team for each side'),
          const SizedBox(height: 4),
          Text('Tap a picked team to review its roster.',
              style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          const SizedBox(height: 8),
          _teamCard('A'),
          const SizedBox(height: 10),
          _teamCard('B'),
          const SizedBox(height: 24),
        ]),
      )),
      Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: _Btn(label: 'Continue', onTap: _nextStep)),
    ]);
  }

  // ── Step 3 ────────────────────────────────

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.checklist_rounded,
          title: 'Review & Publish', subtitle: 'Confirm details'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.accent, width: 1.5)),
          child: Column(children: [
            _Row(label: 'Event',    value: _nameCtrl.text.trim()),
            _Row(label: 'Sport',    value: _sport),
            _Row(label: 'Type',     value: _eventType),
            _Row(label: 'Date',
              value: _eventDate != null
                  ? '${_formatDate()} · ${_formatTime()}' : 'Not set'),
            _Row(label: 'Venue',
              value: _selectedVenue?.name ?? '—', isAccent: true),
            _Row(label: 'GPS',
              value: _selectedVenue != null
                  ? '${_selectedVenue!.lat.toStringAsFixed(4)}, '
                    '${_selectedVenue!.lng.toStringAsFixed(4)}'
                  : '—'),
            _Row(label: 'Players',
              value: '${_addedPlayers.length} registered', isAccent: true),
          ]),
        ),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Registered Players'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: AppTheme.border)),
          child: Column(children: _addedPlayers.asMap().entries.map((e) {
            final isLast = e.key == _addedPlayers.length - 1;
            final p = e.value;
            return Container(
              decoration: BoxDecoration(border: Border(
                bottom: isLast ? BorderSide.none
                    : BorderSide(color: AppTheme.border))),
              child: ListTile(dense: true,
                leading: PlayerAvatar(
                    name: p['fullName'] as String? ?? '',
                    photoUrl: p['photoUrl'] as String?,
                    size: 34, radius: 10, fontSize: 12),
                title: Text(p['fullName'] ?? '', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 13,
                  fontWeight: FontWeight.w600)),
                subtitle: Text(
                  '${p['position'] ?? ''} · '
                  '${(p['team'] as String? ?? 'A') == 'A' ? _teamAName : _teamBName}',
                  style: TextStyle(color: AppTheme.sub, fontSize: 11))));
          }).toList())),
        const SizedBox(height: 20),
        const _SectionLabel(label: 'Visibility'),
        const SizedBox(height: 8),
        Row(children: [
          _Chip(label: '🌐  Public', sel: _isPublic,
              onTap: () => setState(() => _isPublic = true)),
          const SizedBox(width: 8),
          _Chip(label: '🔒  Private', sel: !_isPublic,
              onTap: () => setState(() => _isPublic = false)),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(color: AppTheme.accent)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.gps_fixed_rounded,
                color: AppTheme.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Precise Location Saved', style: TextStyle(
                color: AppTheme.accentText, fontSize: 12,
                fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('${_selectedVenue?.name} GPS coordinates '
                  'will be used for exact map pin placement.',
                style: TextStyle(color: AppTheme.sub,
                    fontSize: 12, height: 1.5)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        _isLoading && !_isDraft
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : _Btn(label: '🏆  Publish Event',
                onTap: () => _onPublish(draft: false)),
        const SizedBox(height: 12),
        _isLoading && _isDraft
            ? const Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : SizedBox(width: double.infinity, height: 54,
                child: OutlinedButton(
                  onPressed: () => _onPublish(draft: true),
                  child: Text('Save as Draft', style: TextStyle(
                    color: AppTheme.sub, fontSize: 15,
                    fontWeight: FontWeight.w700)))),
      ]),
    );
  }

  Widget _field({required TextEditingController ctrl,
    required String hint, required IconData icon,
    TextCapitalization cap = TextCapitalization.none,
    String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl, textCapitalization: cap,
      style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      decoration: _deco(hint: hint, icon: icon),
      validator: validator);
  }

  InputDecoration _deco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.muted, size: 20),
        filled: true, fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(
            vertical: 16, horizontal: 16),
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
        errorStyle: const TextStyle(color: _kErrorRed, fontSize: 11));
}

// ─────────────────────────────────────────────
// Shared Widgets
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon; final String title, subtitle;
  const _SectionHeader({required this.icon,
      required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 40, height: 40,
      decoration: BoxDecoration(color: AppTheme.accentSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent)),
      child: Icon(icon, color: AppTheme.accent, size: 20)),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(color: AppTheme.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w800)),
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

class _Row extends StatelessWidget {
  final String label, value; final bool isAccent;
  const _Row({required this.label, required this.value,
      this.isAccent = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Text(label, style: TextStyle(color: AppTheme.sub, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, textAlign: TextAlign.right,
        style: TextStyle(
          color: isAccent ? AppTheme.accent : AppTheme.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis)),
    ]));
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
        color: sel ? AppTheme.accentText : AppTheme.muted, fontSize: 13,
        fontWeight: sel ? FontWeight.w700 : FontWeight.w500))));
}

class _Btn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(onPressed: onTap, child: Text(label)));
}
// lib/screens/events/edit_event_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/venue.dart';
import '../../services/notification_service.dart';
import '../../services/places_service.dart';
import '../../utils/firestore_helpers.dart';
import 'venue_map_picker_screen.dart';
import '../../utils/error_messages.dart';

const _kRadius = 14.0;
const _kErrorRed = Color(0xFFFF5C5C);
const List<String> _kEventTypes = ['Tournament', 'Friendly', 'League'];
const List<int> _kMaxPlayers = [10, 15, 20];

/// Edits an existing event's metadata — name, description, sport, type,
/// venue, date/time, player cap, and visibility. Deliberately a single form
/// rather than a copy of CreateEventScreen's multi-step wizard, since it
/// never touches the roster: that stays edit_teams_screen.dart's job (team
/// assignment), with add/remove-player left for a future roster-management
/// screen.
class EditEventScreen extends StatefulWidget {
  const EditEventScreen({super.key});
  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  String get _eventId => (Get.arguments as Map?)?['eventId'] as String? ?? '';

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Venue? _selectedVenue;
  String _sport = '';
  String _eventType = '';
  DateTime? _eventDate;
  TimeOfDay? _eventTime;
  int? _maxPlayers;
  bool _isPublic = true;
  List<String> _playerUids = [];

  bool _isLoading = true;
  bool _isSaving = false;

  // Restricted to what this organizer declared (see create_event_screen.dart);
  // the event's already-saved sport is kept as an option even if it's since
  // fallen out of that list, so editing never silently reassigns it.
  List<String> _allowedSports = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc =
        await FirebaseFirestore.instance.collection('events').doc(_eventId).get();
    final data = doc.data() ?? {};
    _nameCtrl.text = data['name'] as String? ?? '';
    _descCtrl.text = data['description'] as String? ?? '';
    _sport = data['sport'] as String? ?? '';
    _eventType = data['eventType'] as String? ?? '';
    final date = asTimestamp(data['eventDate'])?.toDate();
    if (date != null) {
      _eventDate = DateTime(date.year, date.month, date.day);
      _eventTime = TimeOfDay(hour: date.hour, minute: date.minute);
    }
    final venueName = data['venue'] as String?;
    if (venueName != null && venueName.isNotEmpty) {
      _selectedVenue = Venue(
        name: venueName,
        address: data['venueAddress'] as String? ?? '',
        lat: (data['venueLat'] as num?)?.toDouble() ?? 0,
        lng: (data['venueLng'] as num?)?.toDouble() ?? 0,
        type: data['venueType'] as String? ?? '',
      );
    }
    _maxPlayers = data['maxPlayers'] as int?;
    _isPublic = data['isPublic'] as bool? ?? true;
    _playerUids = List<String>.from(data['playerUids'] as List? ?? []);

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final declared =
        (userDoc.data()?['sportsOrganized'] as List?)?.cast<String>().toList() ?? [];
    if (_sport.isNotEmpty && !declared.contains(_sport)) declared.add(_sport);
    _allowedSports = declared;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sport.isEmpty) {
      _snack('Select Sport', 'Please select a sport.');
      return;
    }
    if (_eventType.isEmpty) {
      _snack('Event Type', 'Please select an event type.');
      return;
    }
    if (_eventDate == null) {
      _snack('Select Date', 'Please select a date.');
      return;
    }
    if (_selectedVenue == null) {
      _snack('Select Venue', 'Please select a venue.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final dateTime = DateTime(_eventDate!.year, _eventDate!.month,
          _eventDate!.day, _eventTime?.hour ?? 0, _eventTime?.minute ?? 0);

      final batch = FirebaseFirestore.instance.batch();
      final eventRef =
          FirebaseFirestore.instance.collection('events').doc(_eventId);
      batch.update(eventRef, {
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'sport': _sport,
        'eventType': _eventType,
        'venue': _selectedVenue!.name,
        'venueAddress': _selectedVenue!.address,
        'venueLat': _selectedVenue!.lat,
        'venueLng': _selectedVenue!.lng,
        'venueType': _selectedVenue!.type,
        'eventDate': Timestamp.fromDate(dateTime),
        'maxPlayers': _maxPlayers,
        'isPublic': _isPublic,
      });

      final eventLabel = '${_nameCtrl.text.trim()} on ${_formatDate()}';
      for (final uid in _playerUids) {
        await NotificationService.create(
          userId: uid,
          type: 'event_updated',
          title: 'Event details changed',
          body: '$eventLabel was updated — check what changed.',
          relatedId: _eventId,
          writeBatch: batch,
        );
      }

      await batch.commit();

      if (!mounted) return;
      Get.back();
      Get.snackbar('Event Updated', 'Changes saved.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.accentSurface,
          colorText: AppTheme.accentText,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3));
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
        colorText: isError ? _kErrorRed : AppTheme.textPrimary,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3));
  }

  String _formatDate() => _eventDate == null
      ? 'Select date'
      : DateFormat('MMM dd, yyyy').format(_eventDate!);

  String _formatTime() {
    if (_eventTime == null) return 'Select time';
    final h = _eventTime!.hourOfPeriod == 0 ? 12 : _eventTime!.hourOfPeriod;
    final m = _eventTime!.minute.toString().padLeft(2, '0');
    return '$h:$m ${_eventTime!.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                  primary: AppTheme.accent,
                  onPrimary: AppTheme.buttonFg,
                  surface: AppTheme.card,
                  onSurface: AppTheme.textPrimary)),
          child: child!),
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eventTime ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: ColorScheme.dark(
                  primary: AppTheme.accent,
                  onPrimary: AppTheme.buttonFg,
                  surface: AppTheme.card,
                  onSurface: AppTheme.textPrimary)),
          child: child!),
    );
    if (picked != null) setState(() => _eventTime = picked);
  }

  // ── Venue picker bottom sheet (same pattern as CreateEventScreen) ──

  void _pickVenue() {
    final search = TextEditingController();
    List<Venue> results = [];
    bool isSearching = false;
    bool hasSearched = false;
    bool searchFailed = false;
    bool sheetOpen = true;
    Timer? debounce;
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
            if (q.trim().isEmpty) {
              if (ctx.mounted) {
                setModal(() {
                  results = [];
                  hasSearched = false;
                  searchFailed = false;
                  isSearching = false;
                });
              }
              return;
            }
            if (ctx.mounted) {
              setModal(() {
                isSearching = true;
                searchFailed = false;
              });
            }
            try {
              final found = await PlacesService.searchVenues(q);
              if (!sheetOpen || !ctx.mounted || token != searchToken) return;
              setModal(() {
                results = found;
                isSearching = false;
                hasSearched = true;
                searchFailed = false;
              });
            } catch (e) {
              if (!sheetOpen || !ctx.mounted || token != searchToken) return;
              setModal(() {
                results = [];
                isSearching = false;
                hasSearched = true;
                searchFailed = true;
              });
              _snack(
                  'Search Error',
                  e is PlacesException
                      ? e.message
                      : 'Could not search venues. Check internet connection.',
                  isError: true);
            }
          }

          Future<void> openMapPicker() async {
            final picked = await Navigator.push<Venue>(ctx,
                MaterialPageRoute(builder: (_) => const VenueMapPickerScreen()));
            if (picked != null) {
              setState(() => _selectedVenue = picked);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          }

          Widget dropPinButton() => TextButton.icon(
                onPressed: openMapPicker,
                icon: Icon(Icons.add_location_alt_rounded, color: AppTheme.accent),
                label: Text("Can't find it? Drop a pin",
                    style: TextStyle(color: AppTheme.accent)),
              );

          Widget buildResults(ScrollController ctrl) {
            if (isSearching) {
              return const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.accent, strokeWidth: 2));
            }
            if (!hasSearched) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Type to search for a venue',
                    style: TextStyle(color: AppTheme.muted, fontSize: 13)),
                const SizedBox(height: 12),
                dropPinButton(),
              ]));
            }
            if (searchFailed) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.wifi_off_rounded, color: AppTheme.muted, size: 32),
                const SizedBox(height: 10),
                Text('Something went wrong',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text("We couldn't search venues just now.",
                    style: TextStyle(color: AppTheme.muted, fontSize: 12)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => runSearch(search.text),
                  child: Text('Retry', style: TextStyle(color: AppTheme.accent)),
                ),
                dropPinButton(),
              ]));
            }
            if (results.isEmpty) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('No venues found',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                dropPinButton(),
              ]));
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
            maxChildSize: 0.92,
            builder: (_, ctrl) => Column(children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.border, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Text('Select Venue',
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
                  onChanged: (q) {
                    debounce?.cancel();
                    debounce =
                        Timer(const Duration(milliseconds: 400), () => runSearch(q));
                  },
                  decoration: InputDecoration(
                    hintText: 'Search venue...',
                    hintStyle: TextStyle(color: AppTheme.muted),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: AppTheme.muted, size: 20),
                    filled: true,
                    fillColor: AppTheme.bg,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppTheme.accent, width: 1.5)),
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
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: sel ? AppTheme.accentSurface : AppTheme.cardNested,
                  borderRadius: BorderRadius.circular(8),
                  border: sel ? Border.all(color: AppTheme.accent) : null),
              child: Icon(Icons.location_on_rounded,
                  color: sel ? AppTheme.accent : AppTheme.muted, size: 18)),
          title: Text(v.name,
              style: TextStyle(
                  color: sel ? AppTheme.accentText : AppTheme.textPrimary,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13)),
          subtitle:
              Text(v.address, style: TextStyle(color: AppTheme.muted, fontSize: 11)),
          trailing: sel
              ? Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 20)
              : null,
          onTap: () {
            setState(() => _selectedVenue = v);
            Navigator.pop(sheetCtx);
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border)),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppTheme.textPrimary, size: 16)),
          ),
          const SizedBox(width: 12),
          Text('Edit Event',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field(
              ctrl: _nameCtrl,
              hint: 'Event name',
              icon: Icons.emoji_events_outlined,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Event name is required' : null),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            maxLength: 120,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: _deco(hint: 'Description (optional)', icon: Icons.description_outlined)
                .copyWith(counterStyle: TextStyle(color: AppTheme.sub, fontSize: 11)),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Sport'),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allowedSports
                  .map((s) => _chip(
                      label: s,
                      sel: _sport == s,
                      onTap: () => setState(() => _sport = s)))
                  .toList()),
          const SizedBox(height: 16),
          _sectionLabel('Event Type'),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              children: _kEventTypes
                  .map((t) => _chip(
                      label: t,
                      sel: _eventType == t,
                      onTap: () => setState(() => _eventType = t)))
                  .toList()),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _dateTile()),
            const SizedBox(width: 10),
            Expanded(child: _timeTile()),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickVenue,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(_kRadius),
                  border: Border.all(
                      color: _selectedVenue != null
                          ? AppTheme.accent
                          : AppTheme.border,
                      width: 1.5)),
              child: Row(children: [
                Icon(Icons.location_on_rounded,
                    color: _selectedVenue != null ? AppTheme.accent : AppTheme.muted,
                    size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: _selectedVenue != null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(_selectedVenue!.name,
                                    style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                Text(_selectedVenue!.type,
                                    style:
                                        TextStyle(color: AppTheme.muted, fontSize: 11)),
                              ])
                        : Text('Select Venue (Legazpi City)',
                            style: TextStyle(color: AppTheme.muted, fontSize: 14))),
                Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.muted, size: 20),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          _sectionLabel('Max Players'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ..._kMaxPlayers.map((n) => _chip(
                label: '$n',
                sel: _maxPlayers == n,
                onTap: () => setState(() => _maxPlayers = _maxPlayers == n ? null : n))),
            _chip(
                label: 'No limit',
                sel: _maxPlayers == null,
                onTap: () => setState(() => _maxPlayers = null)),
          ]),
          const SizedBox(height: 20),
          _sectionLabel('Visibility'),
          const SizedBox(height: 8),
          Row(children: [
            _chip(
                label: '🌐  Public',
                sel: _isPublic,
                onTap: () => setState(() => _isPublic = true)),
            const SizedBox(width: 8),
            _chip(
                label: '🔒  Private',
                sel: !_isPublic,
                onTap: () => setState(() => _isPublic = false)),
          ]),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: AppTheme.buttonFg, strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label) => Text(label,
      style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700));

  Widget _chip({required String label, required bool sel, required VoidCallback onTap}) {
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

  Widget _dateTile() => GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                  color: _eventDate != null ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Date', style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.calendar_today_outlined,
                  color: _eventDate != null ? AppTheme.accent : AppTheme.muted, size: 14),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(_formatDate(),
                      style: TextStyle(
                          color: _eventDate != null ? AppTheme.accentText : AppTheme.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
      );

  Widget _timeTile() => GestureDetector(
        onTap: _pickTime,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(_kRadius),
              border: Border.all(
                  color: _eventTime != null ? AppTheme.accent : AppTheme.border,
                  width: 1.5)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Time', style: TextStyle(color: AppTheme.sub, fontSize: 11)),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.access_time_rounded,
                  color: _eventTime != null ? AppTheme.accent : AppTheme.muted, size: 14),
              const SizedBox(width: 6),
              Text(_formatTime(),
                  style: TextStyle(
                      color: _eventTime != null ? AppTheme.accentText : AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      );

  Widget _field(
      {required TextEditingController ctrl,
      required String hint,
      required IconData icon,
      String? Function(String?)? validator}) {
    return TextFormField(
        controller: ctrl,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: _deco(hint: hint, icon: icon),
        validator: validator);
  }

  InputDecoration _deco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.muted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.muted, size: 20),
        filled: true,
        fillColor: AppTheme.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_kRadius), borderSide: BorderSide.none),
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
        errorStyle: const TextStyle(color: _kErrorRed, fontSize: 11),
      );
}

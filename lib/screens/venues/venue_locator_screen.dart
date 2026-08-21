// lib/screens/venues/venue_locator_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/directions_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/firestore_helpers.dart';

// ─────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────

const _kCenter       = LatLng(13.1391, 123.7438);
const _kDefaultZoom  = 13.5;

const List<String> _kFilters = [
  'All', 'Basketball', 'Volleyball', 'Badminton'
];

const Map<String, Color> _kSportColor = {
  'Basketball': Color(0xFFFFB800),
  'Volleyball': Color(0xFF4285F4),
  'Badminton':  Color(0xFF0F9D58),
};

const Map<String, double> _kSportHue = {
  'Basketball': BitmapDescriptor.hueYellow,
  'Volleyball': BitmapDescriptor.hueBlue,
  'Badminton':  BitmapDescriptor.hueGreen,
};

// ─────────────────────────────────────────────
// VenueLocatorScreen
// ─────────────────────────────────────────────

class VenueLocatorScreen extends StatefulWidget {
  const VenueLocatorScreen({super.key});
  @override
  State<VenueLocatorScreen> createState() =>
      _VenueLocatorScreenState();
}

class _VenueLocatorScreenState extends State<VenueLocatorScreen> {
  final Completer<GoogleMapController> _mapCompleter = Completer();

  String  _filter    = 'All';
  bool    _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _events    = [];
  Map<String, dynamic>?      _selected;
  Set<Polyline>              _polylines = {};
  bool   _isRouting  = false;
  String _routeDist  = '';
  String _routeDur   = '';

  // User location — starts at Legazpi center,
  // updated with real GPS if permission granted
  LatLng _userLoc = _kCenter;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _getUserLocation();
  }

  // ── Get real GPS location ─────────────────

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      LocationPermission perm = permission;
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      if (mounted) {
        setState(() {
          _userLoc = LatLng(pos.latitude, pos.longitude);
        });
      }
    } catch (_) {
      // Falls back to Legazpi center if GPS unavailable
    }
  }

  // ── Load events from Firestore ────────────

  Future<void> _loadEvents() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('status',   isEqualTo: 'upcoming')
          .where('isPublic', isEqualTo: true)
          .get();
      if (mounted) setState(() {
        _events    = snap.docs.map((d) => d.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString(); _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered =>
      _filter == 'All'
          ? _events
          : _events.where((e) => e['sport'] == _filter).toList();

  // ── Get exact coords from event ───────────
  // Reads venueLat/venueLng saved by create_event_screen
  // Falls back to Legazpi center if not set

  LatLng _coordsFor(Map<String, dynamic> ev) {
    final lat = ev['venueLat'] as double?;
    final lng = ev['venueLng'] as double?;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return _kCenter;
  }

  // ── Build markers ─────────────────────────

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (final ev in _filtered) {
      final sport  = ev['sport'] as String? ?? '';
      final coords = _coordsFor(ev);
      final hue    = _kSportHue[sport] ?? BitmapDescriptor.hueRed;
      final isSel  = _selected?['eventId'] == ev['eventId'];

      markers.add(Marker(
        markerId: MarkerId(ev['eventId'] as String? ?? ''),
        position: coords,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            isSel ? BitmapDescriptor.hueOrange : hue),
        infoWindow: InfoWindow(
          title:   ev['name'] as String? ?? '',
          snippet: '${ev['sport']} · ${ev['venue']}',
        ),
        onTap: () => _onMarkerTap(ev),
      ));
    }

    // User location marker
    markers.add(Marker(
      markerId: const MarkerId('user_location'),
      position: _userLoc,
      icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure),
      infoWindow: const InfoWindow(title: '📍 Your Location'),
    ));

    return markers;
  }

  // ── Directions via Google Directions API ──

  Future<void> _getDirections(LatLng dest) async {
    setState(() { _isRouting = true; _polylines = {}; });
    try {
      final result = await DirectionsService.fetchDrivingRoute(
          origin: _userLoc, destination: dest);

      final polyline = Polyline(
        polylineId: const PolylineId('route'),
        points:     result.points,
        color:      AppTheme.accent,
        width:      5,
      );

      if (!mounted) return;
      setState(() {
        _polylines = {polyline};
        _routeDist = result.distanceText;
        _routeDur  = result.durationText;
        _isRouting = false;
      });

      // Fit camera to show full route
      final ctrl = await _mapCompleter.future;
      final bounds = _boundsFromLatLngList(
          [_userLoc, dest, ...result.points]);
      ctrl.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 60));
    } catch (e) {
      if (mounted) setState(() { _isRouting = false; });
      final msg = e is DirectionsException
          ? e.message
          : 'Could not get route. Check internet connection.';
      _snack('Directions Error', msg);
    }
  }

  // ── LatLngBounds helper ───────────────────

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;
    for (final p in list) {
      minLat = minLat == null ? p.latitude  : (p.latitude  < minLat ? p.latitude  : minLat);
      maxLat = maxLat == null ? p.latitude  : (p.latitude  > maxLat ? p.latitude  : maxLat);
      minLng = minLng == null ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
      maxLng = maxLng == null ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
    }
    return LatLngBounds(
      southwest: LatLng(minLat! - 0.005, minLng! - 0.005),
      northeast: LatLng(maxLat! + 0.005, maxLng! + 0.005),
    );
  }

  void _clearRoute() => setState(() {
    _polylines = {}; _routeDist = '';
    _routeDur  = ''; _selected  = null;
  });

  // ── Marker tap ────────────────────────────

  void _onMarkerTap(Map<String, dynamic> ev) {
    final dest = _coordsFor(ev);
    setState(() => _selected = ev);
    _animateTo(dest);
    _showSheet(ev, dest);
  }

  Future<void> _animateTo(LatLng dest) async {
    final ctrl = await _mapCompleter.future;
    ctrl.animateCamera(CameraUpdate.newLatLngZoom(dest, 16));
  }

  // ── Bottom sheet ──────────────────────────

  void _showSheet(Map<String, dynamic> ev, LatLng dest) {
    final name  = ev['name']        as String?    ?? '';
    final sport = ev['sport']       as String?    ?? '';
    final type  = ev['eventType']   as String?    ?? '';
    final venue = ev['venue']       as String?    ?? '';
    final addr  = ev['venueAddress'] as String?   ?? venue;
    final count = ev['playerCount'] as int?       ?? 0;
    final date  = asTimestamp(ev['eventDate']);
    final fmt   = date != null
        ? DateFormat('MMM dd, yyyy · hh:mm a').format(date.toDate())
        : 'Date TBA';
    final emoji = sport == 'Basketball' ? '🏀'
        : sport == 'Volleyball' ? '🏐' : '🏸';
    final color = _kSportColor[sport] ?? AppTheme.accent;

    showModalBottomSheet(
      context:            context,
      backgroundColor:    AppTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          Row(children: [
            Container(width: 50, height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color)),
              child: Center(child: Text(emoji,
                  style: const TextStyle(fontSize: 24)))),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(name, style: TextStyle(
                color: AppTheme.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis),
              Text('$sport · $type', style: TextStyle(
                  color: AppTheme.sub, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.accent)),
              child: Text('UPCOMING', style: TextStyle(
                color: AppTheme.accentText, fontSize: 9,
                fontWeight: FontWeight.w700))),
          ]),

          const SizedBox(height: 16),
          Divider(color: AppTheme.border),
          const SizedBox(height: 12),

          _DetailRow(icon: Icons.location_on_outlined,
              label: 'Venue', value: venue),
          const SizedBox(height: 6),
          _DetailRow(icon: Icons.map_outlined,
              label: 'Address', value: addr),
          const SizedBox(height: 6),
          _DetailRow(icon: Icons.calendar_today_outlined,
              label: 'Date & Time', value: fmt),
          const SizedBox(height: 6),
          _DetailRow(icon: Icons.people_outline_rounded,
              label: 'Players', value: '$count registered'),

          if (_routeDist.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accentSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent)),
              child: Row(children: [
                Icon(Icons.directions_car_rounded,
                    color: AppTheme.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  '$_routeDist  •  $_routeDur',
                  style: TextStyle(color: AppTheme.accentText,
                      fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
            ),
          ],

          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: SizedBox(height: 50,
              child: ElevatedButton.icon(
                onPressed: _isRouting ? null : () {
                  Get.back();
                  _getDirections(dest);
                },
                icon: _isRouting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.buttonFg))
                    : const Icon(Icons.directions_rounded, size: 18),
                label: Text(_isRouting
                    ? 'Loading...' : 'Get Directions'),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 50,
              child: OutlinedButton.icon(
                onPressed: () { Get.back(); _clearRoute(); },
                icon: Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.sub),
                label: Text('Close',
                    style: TextStyle(color: AppTheme.sub)),
              ),
            )),
          ]),
        ]),
      ),
    );
  }

  void _snack(String t, String m) => Get.snackbar(t, m,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: AppTheme.card,
    colorText: AppTheme.textPrimary,
    margin: const EdgeInsets.all(16), borderRadius: 12);

  // ── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(child: Column(children: [
        _buildTopBar(),
        _buildFilters(),
        Expanded(child: _isLoading
            ? Center(child: CircularProgressIndicator(
                color: AppTheme.accent, strokeWidth: 2.5))
            : _error != null
                ? _buildError()
                : _buildBody()),
      ])),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 16)),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Game Directory', style: TextStyle(
            color: AppTheme.textPrimary, fontSize: 18,
            fontWeight: FontWeight.w800)),
        Text('Legazpi City · Upcoming events',
            style: TextStyle(color: AppTheme.sub, fontSize: 12)),
      ]),
      const Spacer(),
      if (_polylines.isNotEmpty)
        GestureDetector(
          onTap: _clearRoute,
          child: Container(
            width: 38, height: 38,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.error.withValues(alpha: 0.5))),
            child: Icon(Icons.route_rounded,
                color: AppTheme.error, size: 20)),
        ),
      GestureDetector(
        onTap: _loadEvents,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: AppTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border)),
          child: Icon(Icons.refresh_rounded,
              color: AppTheme.accent, size: 20)),
      ),
    ]),
  );

  Widget _buildFilters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: _kFilters.map((f) {
      final sel = _filter == f;
      return GestureDetector(
        onTap: () => setState(() => _filter = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? AppTheme.accentSurface : AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel ? AppTheme.accent : AppTheme.border,
              width: sel ? 2 : 1.5)),
          child: Text(
            f == 'All' ? '🗺  All Sports'
                : f == 'Basketball' ? '🏀 Basketball'
                : f == 'Volleyball' ? '🏐 Volleyball'
                : '🏸 Badminton',
            style: TextStyle(
              color: sel ? AppTheme.accentText : AppTheme.muted,
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
        ),
      );
    }).toList()),
  );

  Widget _buildBody() {
    final events = _filtered;
    return Column(children: [
      // ── Google Map ────────────────────────
      Expanded(
        flex: 48,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: _kCenter, zoom: _kDefaultZoom),
              onMapCreated: (ctrl) {
                if (!_mapCompleter.isCompleted) {
                  _mapCompleter.complete(ctrl);
                }
              },
              markers:   _buildMarkers(),
              polylines: _polylines,
              myLocationEnabled:       true,
              myLocationButtonEnabled: true,
              mapToolbarEnabled:       false,
              zoomControlsEnabled:     true,
              compassEnabled:          true,
              mapType:                 MapType.normal,
            ),
          ),
        ),
      ),

      // ── Route banner ─────────────────────
      if (_isRouting)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent)),
            child: Row(children: [
              const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent)),
              const SizedBox(width: 10),
              Text('Getting directions via Google Maps...',
                style: TextStyle(color: AppTheme.accentText,
                    fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        )
      else if (_polylines.isNotEmpty && _routeDist.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accentSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent)),
            child: Row(children: [
              Icon(Icons.directions_car_rounded,
                  color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                '$_routeDist  •  $_routeDur',
                style: TextStyle(color: AppTheme.accentText,
                    fontSize: 12, fontWeight: FontWeight.w700))),
              GestureDetector(
                onTap: _clearRoute,
                child: Icon(Icons.close_rounded,
                    color: AppTheme.muted, size: 18)),
            ]),
          ),
        ),

      // ── Legend ───────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Row(children: [
          Text(
            '${events.length} event${events.length == 1 ? '' : 's'}',
            style: TextStyle(color: AppTheme.textPrimary,
                fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          _LegendDot(color: _kSportColor['Basketball']!,
              label: 'Basketball'),
          const SizedBox(width: 10),
          _LegendDot(color: _kSportColor['Volleyball']!,
              label: 'Volleyball'),
          const SizedBox(width: 10),
          _LegendDot(color: _kSportColor['Badminton']!,
              label: 'Badminton'),
        ]),
      ),

      // ── Event list ────────────────────────
      Expanded(
        flex: 52,
        child: events.isEmpty
            ? _buildEmpty()
            : RefreshIndicator(
                color:           AppTheme.accent,
                backgroundColor: AppTheme.card,
                onRefresh:       _loadEvents,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: events.length,
                  itemBuilder: (_, i) {
                    final ev  = events[i];
                    final sel =
                        _selected?['eventId'] == ev['eventId'];
                    return _EventTile(
                      event:      ev,
                      isSelected: sel,
                      onTap: () {
                        setState(() => _selected = ev);
                        _animateTo(_coordsFor(ev));
                        _showSheet(ev, _coordsFor(ev));
                      },
                    );
                  }),
              ),
      ),
    ]);
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accent)),
        child: const Center(child: Text('🗺',
            style: TextStyle(fontSize: 28)))),
      const SizedBox(height: 14),
      Text('No upcoming events', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(_filter == 'All'
          ? 'Events will appear here once created'
          : 'No upcoming $_filter events',
        style: TextStyle(color: AppTheme.sub, fontSize: 13)),
    ]),
  );

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.wifi_off_rounded, color: AppTheme.muted, size: 40),
      const SizedBox(height: 12),
      Text('Could not load events', style: TextStyle(
          color: AppTheme.textPrimary, fontSize: 15,
          fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      GestureDetector(onTap: _loadEvents,
        child: Text('Tap to retry', style: TextStyle(
            color: AppTheme.accent, fontSize: 13,
            fontWeight: FontWeight.w600))),
    ]),
  );
}

// ─────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon; final String label, value;
  const _DetailRow({required this.icon,
      required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 30, height: 30,
      decoration: BoxDecoration(color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppTheme.muted, size: 15)),
    const SizedBox(width: 10),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: AppTheme.muted, fontSize: 10)),
      Text(value, style: TextStyle(color: AppTheme.textPrimary,
          fontSize: 12, fontWeight: FontWeight.w600)),
    ])),
  ]);
}

class _LegendDot extends StatelessWidget {
  final Color color; final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8,
      decoration: BoxDecoration(
          color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(
        color: AppTheme.muted, fontSize: 10)),
  ]);
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isSelected; final VoidCallback onTap;
  const _EventTile({required this.event,
      required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final name  = event['name']        as String?    ?? '';
    final sport = event['sport']       as String?    ?? '';
    final venue = event['venue']       as String?    ?? '';
    final count = event['playerCount'] as int?       ?? 0;
    final date  = asTimestamp(event['eventDate']);
    final fmt   = date != null
        ? DateFormat('MMM dd').format(date.toDate()) : '';
    final emoji = sport == 'Basketball' ? '🏀'
        : sport == 'Volleyball' ? '🏐' : '🏸';
    final color = _kSportColor[sport] ?? AppTheme.accent;
    final hasGps = event['venueLat'] != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentSurface : AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 2 : 1)),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color)),
            child: Center(child: Text(emoji,
                style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(name, style: TextStyle(
              color: isSelected
                  ? AppTheme.accentText : AppTheme.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(
                '$venue · $count players',
                style: TextStyle(color: AppTheme.sub, fontSize: 11),
                overflow: TextOverflow.ellipsis)),
              if (hasGps) ...[
                const SizedBox(width: 4),
                Icon(Icons.gps_fixed_rounded,
                    color: AppTheme.success, size: 10),
              ],
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmt, style: TextStyle(
              color: AppTheme.accentText, fontSize: 11,
              fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.muted, size: 18),
          ]),
        ]),
      ),
    );
  }
}
// lib/screens/venues/venue_locator_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────

const _kOrsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImU5ZTFmODZkZjgwNTRiN2ZhMmIzYzI0M2VmZDViNTQwIiwiaCI6Im11cm11cjY0In0=';
const _kCenter    = LatLng(13.1391, 123.7438);

const Map<String, LatLng> _kVenueCoords = {
  'legazpi sports complex':  LatLng(13.1420, 123.7391),
  'legazpi city astrodome':  LatLng(13.1355, 123.7406),
  'astrodome':               LatLng(13.1355, 123.7406),
  'penaranda park':          LatLng(13.1403, 123.7438),
  'pennaranda park':         LatLng(13.1403, 123.7438),
  'city hall':               LatLng(13.1397, 123.7430),
  'legazpi city hall':       LatLng(13.1397, 123.7430),
  'sagumbayan court':        LatLng(13.1310, 123.7450),
  'bonot gym':               LatLng(13.1280, 123.7480),
  'rawis sports center':     LatLng(13.1270, 123.7500),
  'gogon gym':               LatLng(13.1500, 123.7360),
  'taysan gym':              LatLng(13.1450, 123.7460),
  'cabangan sports center':  LatLng(13.1330, 123.7520),
  'landing sports complex':  LatLng(13.1370, 123.7420),
};

const List<String> _kFilters = [
  'All', 'Basketball', 'Volleyball', 'Badminton'
];

const Map<String, Color> _kSportColor = {
  'Basketball': Color(0xFFFFB800),
  'Volleyball': Color(0xFF4285F4),
  'Badminton':  Color(0xFF0F9D58),
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
  final MapController _mapCtrl = MapController();

  String  _filter       = 'All';
  bool    _isLoading    = true;
  String? _error;

  List<Map<String, dynamic>> _events      = [];
  Map<String, dynamic>?      _selected;
  List<LatLng>               _routePoints = [];
  bool    _isRouting    = false;
  String  _routeDist    = '';
  String  _routeDur     = '';

  // Demo user location — Legazpi City center
  final LatLng _userLoc = const LatLng(13.1391, 123.7438);

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // ── Load events ───────────────────────────

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

  // ── Coords ────────────────────────────────

  LatLng _coordsFor(String venue) {
    final key = venue.toLowerCase().trim();
    for (final k in _kVenueCoords.keys) {
      if (key.contains(k) || k.contains(key)) {
        return _kVenueCoords[k]!;
      }
    }
    // Unique offset so stacked venues spread out
    return LatLng(
      _kCenter.latitude  + (venue.hashCode % 100) * 0.0005,
      _kCenter.longitude + (venue.hashCode % 50)  * 0.0005,
    );
  }

  // ── Directions ────────────────────────────

  // ── Directions via OpenRouteService API ─────

  Future<void> _getDirections(LatLng dest) async {
    setState(() { _isRouting = true; _routePoints = []; });
    try {
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car'
        '?api_key=$_kOrsApiKey'
        '&start=${_userLoc.longitude},${_userLoc.latitude}'
        '&end=${dest.longitude},${dest.latitude}',
      );

      final res = await http.get(url, headers: {
        'Accept':       'application/json, application/geo+json',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body);
        final feature = data['features'][0];
        final coords  = feature['geometry']['coordinates'] as List;
        final segment = feature['properties']['segments'][0];
        final distM   = (segment['distance'] as num).toDouble();
        final durSec  = (segment['duration'] as num).toDouble();

        final points  = coords.map((c) =>
            LatLng((c[1] as num).toDouble(),
                   (c[0] as num).toDouble())).toList();

        final distKm = distM >= 1000
            ? '${(distM / 1000).toStringAsFixed(1)} km'
            : '${distM.toInt()} m';
        final durMin = (durSec / 60).ceil();
        final durStr = durMin >= 60
            ? '${durMin ~/ 60}h ${durMin % 60}min'
            : '$durMin min';

        if (!mounted) return;
        setState(() {
          _routePoints = points;
          _routeDist   = distKm;
          _routeDur    = durStr;
          _isRouting   = false;
        });

        // Auto-fit map to show full route
        if (points.length > 1) {
          final minLat = points.map((p) => p.latitude)
              .reduce((a, b) => a < b ? a : b);
          final maxLat = points.map((p) => p.latitude)
              .reduce((a, b) => a > b ? a : b);
          final minLng = points.map((p) => p.longitude)
              .reduce((a, b) => a < b ? a : b);
          final maxLng = points.map((p) => p.longitude)
              .reduce((a, b) => a > b ? a : b);
          _mapCtrl.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds(
              LatLng(minLat - 0.003, minLng - 0.003),
              LatLng(maxLat + 0.003, maxLng + 0.003),
            ),
            padding: const EdgeInsets.all(40)));
        }
      } else {
        throw Exception('ORS error ${res.statusCode}: ${res.body}');
      }
    } on TimeoutException {
      if (mounted) setState(() { _isRouting = false; });
      _snack('Timeout', 'Request timed out. Check your connection.');
    } catch (e) {
      if (mounted) setState(() { _isRouting = false; });
      _snack('Directions Error', e.toString());
    }
  }


  void _clearRoute() => setState(() {
    _routePoints = []; _routeDist = '';
    _routeDur    = ''; _selected  = null;
  });

  void _onMarkerTap(Map<String, dynamic> ev) {
    final dest = _coordsFor(ev['venue'] as String? ?? '');
    setState(() => _selected = ev);
    _mapCtrl.move(dest, 15);
    _showSheet(ev, dest);
  }

  // ── Bottom sheet ──────────────────────────

  void _showSheet(Map<String, dynamic> ev, LatLng dest) {
    final name  = ev['name']        as String?    ?? '';
    final sport = ev['sport']       as String?    ?? '';
    final type  = ev['eventType']   as String?    ?? '';
    final venue = ev['venue']       as String?    ?? '';
    final count = ev['playerCount'] as int?       ?? 0;
    final date  = ev['eventDate']   as Timestamp?;
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
            Container(
              width: 50, height: 50,
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
              Text('$sport · $type',
                style: TextStyle(color: AppTheme.sub, fontSize: 12)),
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
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.calendar_today_outlined,
              label: 'Date & Time', value: fmt),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.people_outline_rounded,
              label: 'Players', value: '$count registered'),
          if (_routeDist.isNotEmpty) ...[
            const SizedBox(height: 10),
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
                label: Text(
                    _isRouting ? 'Loading...' : 'Get Directions'),
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

  // ── Markers ───────────────────────────────

  List<Marker> _buildMarkers() {
    final out = <Marker>[];
    for (final ev in _filtered) {
      final venue  = ev['venue'] as String? ?? '';
      final sport  = ev['sport'] as String? ?? '';
      final coords = _coordsFor(venue);
      final color  = _kSportColor[sport] ?? AppTheme.accent;
      final isSel  = _selected?['eventId'] == ev['eventId'];
      final sz     = isSel ? 52.0 : 40.0;

      out.add(Marker(
        point: coords, width: sz + 8, height: sz + 18,
        child: GestureDetector(
          onTap: () => _onMarkerTap(ev),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: sz, height: sz,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: isSel ? 14 : 6,
                  spreadRadius: isSel ? 2 : 0)]),
              child: Center(child: Text(
                sport == 'Basketball' ? '🏀'
                    : sport == 'Volleyball' ? '🏐' : '🏸',
                style: TextStyle(
                    fontSize: isSel ? 22 : 16)))),
            Container(width: 2.5, height: 10, color: color),
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle)),
          ]),
        ),
      ));
    }

    // Blue dot for user location
    out.add(Marker(
      point: _userLoc, width: 24, height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue, shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(
              color: Colors.blue.withValues(alpha: 0.4),
              blurRadius: 8, spreadRadius: 2)]),
      ),
    ));
    return out;
  }

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
            : _error != null ? _buildError()
            : _buildBody()),
      ])),
    );
  }

  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      GestureDetector(
        onTap: () => Get.back(),
        child: Container(
          width: 38, height: 38,
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
      if (_routePoints.isNotEmpty)
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
      // ── Map ──────────────────────────────
      Expanded(flex: 48, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: FlutterMap(
            mapController: _mapCtrl,
            options: const MapOptions(
              initialCenter: _kCenter,
              initialZoom:   13.5,
              maxZoom:       18.0,
              minZoom:       10.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.homegrown.homegrown',
                maxZoom: 18),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points:           _routePoints,
                    color:            AppTheme.accent,
                    strokeWidth:      4.5,
                    borderColor:      Colors.white,
                    borderStrokeWidth: 1.5),
                ]),
              MarkerLayer(markers: _buildMarkers()),
              const SimpleAttributionWidget(
                source: Text('© OpenStreetMap contributors',
                    style: TextStyle(fontSize: 9))),
            ],
          ),
        ),
      )),

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
              Text('Calculating route...',
                style: TextStyle(color: AppTheme.accentText,
                    fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        )
      else if (_routePoints.isNotEmpty && _routeDist.isNotEmpty)
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
              Expanded(child: Text('$_routeDist  •  $_routeDur',
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
          _LegendDot(
              color: _kSportColor['Basketball']!, label: 'Basketball'),
          const SizedBox(width: 10),
          _LegendDot(
              color: _kSportColor['Volleyball']!, label: 'Volleyball'),
          const SizedBox(width: 10),
          _LegendDot(
              color: _kSportColor['Badminton']!,  label: 'Badminton'),
        ]),
      ),

      // ── Event list ────────────────────────
      Expanded(
        flex: 52,
        child: events.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: events.length,
                itemBuilder: (_, i) {
                  final ev  = events[i];
                  final sel =
                      _selected?['eventId'] == ev['eventId'];
                  return _EventTile(
                    event: ev, isSelected: sel,
                    onTap: () {
                      _onMarkerTap(ev);
                      _mapCtrl.move(
                          _coordsFor(ev['venue'] as String? ?? ''),
                          15);
                    });
                }),
      ),
    ]);
  }

  Widget _buildEmpty() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: AppTheme.accentSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.accent)),
        child: const Center(
            child: Text('🗺', style: TextStyle(fontSize: 28)))),
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
    Container(width: 32, height: 32,
      decoration: BoxDecoration(color: AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppTheme.muted, size: 16)),
    const SizedBox(width: 10),
    Expanded(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: AppTheme.muted, fontSize: 11)),
      Text(value, style: TextStyle(color: AppTheme.textPrimary,
          fontSize: 13, fontWeight: FontWeight.w600)),
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
    final date  = event['eventDate']   as Timestamp?;
    final fmt   = date != null
        ? DateFormat('MMM dd').format(date.toDate()) : '';
    final emoji = sport == 'Basketball' ? '🏀'
        : sport == 'Volleyball' ? '🏐' : '🏸';
    final color = _kSportColor[sport] ?? AppTheme.accent;

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
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
              color: isSelected
                  ? AppTheme.accentText : AppTheme.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$venue · $count players',
              style: TextStyle(color: AppTheme.sub, fontSize: 11),
              overflow: TextOverflow.ellipsis),
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
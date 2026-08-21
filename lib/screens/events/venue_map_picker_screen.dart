// lib/screens/events/venue_map_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/venue.dart';
import '../../services/geocoding_service.dart';
import '../../theme/app_theme.dart';

const _kCenter = LatLng(13.1391, 123.7438);

/// Manual venue-pin fallback for when Places search finds nothing —
/// tap the map to set a venue's exact location, mirroring how native
/// Google Maps lets you drop a pin at an unlisted spot.
class VenueMapPickerScreen extends StatefulWidget {
  const VenueMapPickerScreen({super.key});
  @override
  State<VenueMapPickerScreen> createState() => _VenueMapPickerScreenState();
}

class _VenueMapPickerScreenState extends State<VenueMapPickerScreen> {
  LatLng? _tapped;
  String? _address;
  bool _isResolving = false;
  int _requestToken = 0;

  Future<void> _onTap(LatLng point) async {
    _requestToken++;
    final currentToken = _requestToken;

    setState(() {
      _tapped = point;
      _address = null;
      _isResolving = true;
    });
    try {
      final address = await GeocodingService.reverseGeocode(point);
      if (!mounted || _requestToken != currentToken) return;
      setState(() {
        _address = address;
        _isResolving = false;
      });
    } catch (e) {
      if (!mounted || _requestToken != currentToken) return;
      setState(() {
        _address = null;
        _isResolving = false;
      });
    }
  }

  void _confirm() {
    if (_tapped == null) return;
    final label = _address ??
        '${_tapped!.latitude.toStringAsFixed(5)}, '
            '${_tapped!.longitude.toStringAsFixed(5)}';
    Navigator.pop(
      context,
      Venue(
        name: label,
        address: label,
        lat: _tapped!.latitude,
        lng: _tapped!.longitude,
        type: 'Venue',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        title: Text('Drop a Pin', style: TextStyle(color: AppTheme.textPrimary)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(target: _kCenter, zoom: 13.5),
          onTap: _onTap,
          markers: _tapped == null
              ? {}
              : {Marker(markerId: const MarkerId('tapped'), position: _tapped!)},
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _tapped == null
                    ? "Tap the map to set this venue's location"
                    : (_isResolving
                        ? 'Looking up address...'
                        : (_address ??
                            'No address found — will use coordinates only')),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _tapped == null ? null : _confirm,
                  child: const Text('Confirm Location'),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

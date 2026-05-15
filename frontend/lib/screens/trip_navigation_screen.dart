import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as osm;
import 'package:url_launcher/url_launcher.dart';

import '../theme/feu_theme.dart';
import '../utils/geo_estimate.dart';
import '../utils/phone_launch.dart';
import 'user_profile_page.dart';

/// Itinéraire vers le client après acceptation.
/// Carte en tuiles OSM (Carto) — pas de SDK Google Maps (évite l’erreur MapTypeId sur le Web).
class TripNavigationScreen extends StatefulWidget {
  const TripNavigationScreen({
    super.key,
    required this.requestId,
    required this.clientName,
    required this.clientLat,
    required this.clientLng,
    this.clientPhone,
    this.clientAddress,
    this.clientUser,
  });

  final int requestId;
  final String clientName;
  final double clientLat;
  final double clientLng;
  final String? clientPhone;
  final String? clientAddress;
  final Map<String, dynamic>? clientUser;

  @override
  State<TripNavigationScreen> createState() => _TripNavigationScreenState();
}

class _TripNavigationScreenState extends State<TripNavigationScreen> {
  final MapController _mapCtrl = MapController();
  double? _mechLat;
  double? _mechLng;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  Future<void> _initPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _mechLat = pos.latitude;
        _mechLng = pos.longitude;
      });
      _fitBoundsSoon();
      _posSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25,
        ),
      ).listen((p) {
        if (!mounted) return;
        setState(() {
          _mechLat = p.latitude;
          _mechLng = p.longitude;
        });
      });
    } catch (_) {}
  }

  void _fitBoundsSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ml = _mechLat;
      final mg = _mechLng;
      if (ml != null && mg != null) {
        try {
          _mapCtrl.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(
                osm.LatLng(
                  ml < widget.clientLat ? ml : widget.clientLat,
                  mg < widget.clientLng ? mg : widget.clientLng,
                ),
                osm.LatLng(
                  ml > widget.clientLat ? ml : widget.clientLat,
                  mg > widget.clientLng ? mg : widget.clientLng,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(48, 48, 48, 120),
            ),
          );
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  double? get _distanceKm {
    if (_mechLat == null || _mechLng == null) return null;
    return haversineKm(_mechLat!, _mechLng!, widget.clientLat, widget.clientLng);
  }

  Duration? get _eta {
    final d = _distanceKm;
    if (d == null) return null;
    return estimateDriveDuration(d);
  }

  Future<void> _openExternalNavigation() async {
    String uri =
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${widget.clientLat},${widget.clientLng}'
        '&travelmode=driving';
    if (_mechLat != null && _mechLng != null) {
      uri += '&origin=$_mechLat,$_mechLng';
    }
    final parsed = Uri.parse(uri);
    if (await canLaunchUrl(parsed)) {
      await launchUrl(parsed, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = _distanceKm;
    final eta = _eta;
    final center = osm.LatLng(
      _mechLat ?? widget.clientLat,
      _mechLng ?? widget.clientLng,
    );

    final markers = <Marker>[
      Marker(
        point: osm.LatLng(widget.clientLat, widget.clientLng),
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Tooltip(
          message: widget.clientName,
          child: Icon(Icons.location_on_rounded, color: Colors.blue.shade700, size: 40),
        ),
      ),
      if (_mechLat != null && _mechLng != null)
        Marker(
          point: osm.LatLng(_mechLat!, _mechLng!),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Tooltip(
            message: 'Ma position',
            child: Icon(Icons.navigation_rounded, color: FeuTheme.ember, size: 36),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: FeuTheme.paper,
      appBar: AppBar(
        backgroundColor: FeuTheme.deepBlue,
        foregroundColor: Colors.white,
        title: Text('Vers le client', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 5,
                maxZoom: 18,
                onMapReady: _fitBoundsSoon,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.mechassist',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Material(
            elevation: 12,
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.clientName,
                    style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  if (widget.clientAddress != null && widget.clientAddress!.trim().isNotEmpty)
                    Text(
                      widget.clientAddress!,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatChip(
                        icon: Icons.straighten_rounded,
                        label: dist != null ? '${dist.toStringAsFixed(1)} km' : '—',
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        icon: Icons.schedule_rounded,
                        label: eta != null ? formatEta(eta) : '—',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openExternalNavigation,
                    icon: const Icon(Icons.navigation_rounded),
                    label: const Text('Lancer l’itinéraire (Google Maps)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FeuTheme.deepBlue,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (normalizePhoneForDial(widget.clientPhone) != null)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => launchTelDialer(context, widget.clientPhone),
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Appeler'),
                          ),
                        ),
                      if (widget.clientUser != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => UserProfilePage(
                                    user: widget.clientUser!,
                                    subtitle: 'Demande #${widget.requestId}',
                                    onNavigate: _openExternalNavigation,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person_outline_rounded),
                            label: const Text('Profil'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: FeuTheme.deepBlue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: FeuTheme.deepBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

import '../services/google_maps_script_loader.dart';
import '../theme/feu_theme.dart';

/// Point client sur la carte mécano (demande d’intervention).
class MapJobSite {
  const MapJobSite({
    required this.lat,
    required this.lng,
    required this.label,
    this.id,
  });

  final double lat;
  final double lng;
  final String label;
  final String? id;
}

/// Carte : position du mécano + lieux clients (demandes).
class InterventionLocationsMap extends StatefulWidget {
  const InterventionLocationsMap({
    super.key,
    required this.mechanicLat,
    required this.mechanicLng,
    required this.jobSites,
    this.googleMapsWebApiKey,
  });

  final double mechanicLat;
  final double mechanicLng;
  final List<MapJobSite> jobSites;
  final String? googleMapsWebApiKey;

  @override
  State<InterventionLocationsMap> createState() => _InterventionLocationsMapState();
}

class _InterventionLocationsMapState extends State<InterventionLocationsMap> {
  bool _webGmapsLoading = false;
  bool _webGmapsReady = true;
  Object? _webGmapsError;

  @override
  void initState() {
    super.initState();
    final key = widget.googleMapsWebApiKey?.trim() ?? '';
    if (kIsWeb && key.isNotEmpty) {
      _webGmapsLoading = true;
      _webGmapsReady = false;
    }
    _prepareWebGoogleMaps();
  }

  @override
  void didUpdateWidget(InterventionLocationsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.googleMapsWebApiKey != widget.googleMapsWebApiKey) {
      final key = widget.googleMapsWebApiKey?.trim() ?? '';
      setState(() {
        if (kIsWeb && key.isNotEmpty) {
          _webGmapsLoading = true;
          _webGmapsReady = false;
          _webGmapsError = null;
        } else {
          _webGmapsLoading = false;
          _webGmapsReady = true;
          _webGmapsError = null;
        }
      });
      _prepareWebGoogleMaps();
    }
  }

  Future<void> _prepareWebGoogleMaps() async {
    final key = widget.googleMapsWebApiKey?.trim() ?? '';
    if (!kIsWeb || key.isEmpty) {
      if (mounted) {
        setState(() {
          _webGmapsLoading = false;
          _webGmapsReady = true;
          _webGmapsError = null;
        });
      }
      return;
    }
    try {
      await loadGoogleMapsScript(key);
      if (!mounted) return;
      setState(() {
        _webGmapsLoading = false;
        _webGmapsReady = true;
        _webGmapsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _webGmapsLoading = false;
        _webGmapsReady = true;
        _webGmapsError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = widget.googleMapsWebApiKey?.trim() ?? '';
    final useGoogleWeb =
        kIsWeb && key.isNotEmpty && _webGmapsReady && _webGmapsError == null && !_webGmapsLoading;

    if (kIsWeb && key.isNotEmpty && _webGmapsLoading) {
      return const Center(child: CircularProgressIndicator(color: FeuTheme.ember));
    }

    if (useGoogleWeb) {
      return _buildGoogleMap();
    }
    return _buildFlutterMap();
  }

  Widget _buildGoogleMap() {
    final center = gmaps.LatLng(widget.mechanicLat, widget.mechanicLng);
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('mechanic'),
        position: center,
        infoWindow: const gmaps.InfoWindow(title: 'Ma position'),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueOrange),
      ),
      ...widget.jobSites.map((j) {
        final id = j.id ?? '${j.lat}_${j.lng}';
        return gmaps.Marker(
          markerId: gmaps.MarkerId('job_$id'),
          position: gmaps.LatLng(j.lat, j.lng),
          infoWindow: gmaps.InfoWindow(title: j.label),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
        );
      }),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 12),
      markers: markers,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: osm.LatLng(widget.mechanicLat, widget.mechanicLng),
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.mechassist',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: osm.LatLng(widget.mechanicLat, widget.mechanicLng),
              width: 36,
              height: 36,
              child: const Icon(Icons.build_circle, color: FeuTheme.ember, size: 30),
            ),
            ...widget.jobSites.map(
              (j) => Marker(
                point: osm.LatLng(j.lat, j.lng),
                width: 32,
                height: 32,
                child: const Icon(Icons.person_pin_circle, color: FeuTheme.deepBlue, size: 28),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as osm;

import '../services/google_maps_script_loader.dart';

/// Carte des mécaniciens : Google Maps sur le Web si [googleMapsWebApiKey] est fourni,
/// sinon tuiles Carto (compatibles navigateur, sans clé).
class MechanicNearbyMap extends StatefulWidget {
  const MechanicNearbyMap({
    super.key,
    required this.clientLat,
    required this.clientLng,
    required this.mechanics,
    this.googleMapsWebApiKey,
  });

  final double clientLat;
  final double clientLng;
  final List<Map<String, dynamic>> mechanics;
  final String? googleMapsWebApiKey;

  @override
  State<MechanicNearbyMap> createState() => _MechanicNearbyMapState();
}

class _MechanicNearbyMapState extends State<MechanicNearbyMap> {
  bool _webGmapsLoading = false;
  bool _webGmapsReady = true;
  Object? _webGmapsError;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _prepareWebGoogleMaps();
    }
  }

  @override
  void didUpdateWidget(MechanicNearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb && oldWidget.googleMapsWebApiKey != widget.googleMapsWebApiKey) {
      setState(() {
        _webGmapsLoading = false;
        _webGmapsReady = true;
        _webGmapsError = null;
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
      if (!mounted) {
        return;
      }
      setState(() {
        _webGmapsLoading = false;
        _webGmapsReady = true;
        _webGmapsError = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
    if (kIsWeb) {
      return _buildFlutterMap();
    }

    final useGoogleWeb =
        key.isNotEmpty && _webGmapsReady && _webGmapsError == null && !_webGmapsLoading;

    if (key.isNotEmpty && _webGmapsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (useGoogleWeb) {
      return _buildGoogleMap();
    }
    return _buildFlutterMap();
  }

  Widget _buildGoogleMap() {
    final center = gmaps.LatLng(widget.clientLat, widget.clientLng);
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('client'),
        position: center,
        infoWindow: const gmaps.InfoWindow(title: 'Ta position'),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueAzure),
      ),
      ...widget.mechanics.map((m) {
        final ml = (m['latitude'] as num?)?.toDouble();
        final mg = (m['longitude'] as num?)?.toDouble();
        if (ml == null || mg == null) {
          return null;
        }
        final id = m['id']?.toString() ?? '${ml}_$mg';
        return gmaps.Marker(
          markerId: gmaps.MarkerId('m_$id'),
          position: gmaps.LatLng(ml, mg),
          infoWindow: gmaps.InfoWindow(title: m['name']?.toString() ?? 'Mécanicien'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(gmaps.BitmapDescriptor.hueRed),
        );
      }).whereType<gmaps.Marker>(),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(target: center, zoom: 13),
      markers: markers,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildFlutterMap() {
    return FlutterMap(
      options: MapOptions(
        initialCenter: osm.LatLng(widget.clientLat, widget.clientLng),
        initialZoom: 13,
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
              point: osm.LatLng(widget.clientLat, widget.clientLng),
              width: 36,
              height: 36,
              child: const Icon(Icons.my_location, color: Color(0xFF0F4C75), size: 28),
            ),
            ...widget.mechanics.map((m) {
              final ml = (m['latitude'] as num?)?.toDouble();
              final mg = (m['longitude'] as num?)?.toDouble();
              if (ml == null || mg == null) {
                return null;
              }
              return Marker(
                point: osm.LatLng(ml, mg),
                width: 32,
                height: 32,
                child: const Icon(Icons.build_circle, color: Colors.red, size: 26),
              );
            }).whereType<Marker>(),
          ],
        ),
      ],
    );
  }
}

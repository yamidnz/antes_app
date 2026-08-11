import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import '../services/alert_settings_repository.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class SafeZone {
  final String name;
  final String type;
  final double lat;
  final double lon;
  final double distanceKm;
  SafeZone({required this.name, required this.type, required this.lat, required this.lon, required this.distanceKm});
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

enum _ZonesState { loading, ok, empty, error }

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService();
  Position? _position;
  List<SafeZone> _zones = [];
  bool _loadingLocation = true;
  String? _locationError;
  _ZonesState _zonesState = _ZonesState.loading;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loadingLocation = true; _locationError = null; _zonesState = _ZonesState.loading; });

    final ok = await _locationService.ensurePermission();
    if (!ok) {
      setState(() { _loadingLocation = false; _locationError = 'Activa el permiso de ubicación (y el GPS del sistema) para ver el mapa y las zonas seguras.'; });
      return;
    }

    Position pos;
    try {
      pos = await _locationService.getPreciseLocation(timeout: const Duration(seconds: 20));
    } catch (_) {
      setState(() { _loadingLocation = false; _locationError = 'No pudimos obtener tu ubicación GPS. Verifica que el GPS esté activado y que tengas buena señal.'; });
      return;
    }

    // El mapa se muestra apenas tengamos la ubicación — las zonas se
    // buscan aparte, con su propio indicador, para que nunca se sienta
    // que la pantalla completa quedó "pegada" cargando.
    setState(() { _position = pos; _loadingLocation = false; });
    AlertSettingsRepository().saveLastKnownLocation(pos.latitude, pos.longitude);
    _loadZones(pos.latitude, pos.longitude);
  }

  Future<void> _loadZones(double lat, double lon) async {
    setState(() => _zonesState = _ZonesState.loading);
    try {
      final zones = await _fetchSafeZones(lat, lon).timeout(const Duration(seconds: 14));
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _zonesState = zones.isEmpty ? _ZonesState.empty : _ZonesState.ok;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _zonesState = _ZonesState.error);
    }
  }

  // Varios espejos de Overpass: el servidor principal (overpass-api.de) se
  // satura o cae con frecuencia. En vez de probarlos uno por uno (lo que
  // podía sentirse como un bucle eterno), los lanzamos en paralelo y nos
  // quedamos con el primero que responda.
  static const _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  String _buildQuery(double lat, double lon, int radiusM) {
    return '[out:json][timeout:12];'
        '(node["leisure"="park"](around:$radiusM,$lat,$lon);'
        'way["leisure"="park"](around:$radiusM,$lat,$lon);'
        'node["leisure"="pitch"](around:$radiusM,$lat,$lon);'
        'way["leisure"="recreation_ground"](around:$radiusM,$lat,$lon);'
        'node["amenity"="marketplace"](around:$radiusM,$lat,$lon);'
        'node["place"="square"](around:$radiusM,$lat,$lon);'
        'way["place"="square"](around:$radiusM,$lat,$lon);'
        'node["amenity"="school"](around:$radiusM,$lat,$lon););'
        'out center 20;';
  }

  List<SafeZone> _parseZones(String body, double lat, double lon) {
    final data = jsonDecode(body) as Map<String, dynamic>;
    final elements = (data['elements'] as List<dynamic>);
    final zones = <SafeZone>[];
    for (final el in elements) {
      final tags = (el['tags'] as Map<String, dynamic>?) ?? {};
      final zlat = (el['lat'] ?? el['center']?['lat']) as num?;
      final zlon = (el['lon'] ?? el['center']?['lon']) as num?;
      if (zlat == null || zlon == null) continue;
      String type;
      if (tags['leisure'] == 'park') {
        type = 'Parque';
      } else if (tags['leisure'] == 'pitch' || tags['leisure'] == 'recreation_ground') {
        type = 'Cancha / zona deportiva abierta';
      } else if (tags['amenity'] == 'marketplace') {
        type = 'Plaza de mercado';
      } else if (tags['place'] == 'square') {
        type = 'Plaza';
      } else if (tags['amenity'] == 'school') {
        type = 'Institución educativa (patio abierto)';
      } else {
        type = 'Espacio abierto';
      }
      final name = tags['name'] as String? ?? type;
      final dist = Geolocator.distanceBetween(lat, lon, zlat.toDouble(), zlon.toDouble()) / 1000.0;
      zones.add(SafeZone(name: name, type: type, lat: zlat.toDouble(), lon: zlon.toDouble(), distanceKm: dist));
    }
    zones.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return zones;
  }

  Future<List<SafeZone>> _fetchOnce(double lat, double lon, int radiusM) async {
    final query = _buildQuery(lat, lon, radiusM);
    final completer = Completer<List<SafeZone>>();
    var pending = _overpassMirrors.length;

    for (final mirror in _overpassMirrors) {
      http.post(Uri.parse(mirror), body: {'data': query}).timeout(const Duration(seconds: 12)).then((res) {
        if (completer.isCompleted) return;
        if (res.statusCode == 200) {
          final zones = _parseZones(res.body, lat, lon);
          if (zones.isNotEmpty) {
            completer.complete(zones);
            return;
          }
        }
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete([]);
      }).catchError((_) {
        pending--;
        if (pending == 0 && !completer.isCompleted) completer.complete([]);
      });
    }
    return completer.future;
  }

  Future<List<SafeZone>> _fetchSafeZones(double lat, double lon) async {
    // Un solo radio amplio de entrada: si no hay nada, ampliamos una vez
    // más. Ya no hacemos 3 radios × 3 espejos secuenciales (eso era lo que
    // se sentía como un bucle infinito).
    final first = await _fetchOnce(lat, lon, 3000);
    if (first.isNotEmpty) return first.take(10).toList();
    final second = await _fetchOnce(lat, lon, 7000);
    return second.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zonas seguras', style: AppTheme.display())),
      body: _loadingLocation
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _locationError != null
              ? _buildLocationError()
              : _buildContent(),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_locationError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dim)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final center = ll.LatLng(_position!.latitude, _position!.longitude);
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              TileLayer(
                // Sin el placeholder {r}: si queda sin resolver, todas las
                // peticiones de tiles fallan y el mapa se ve negro — ese
                // era el bug de la versión anterior.
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'co.antesapp.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: center,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(color: AppColors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  ),
                ),
                ..._zones.map((z) => Marker(
                      point: ll.LatLng(z.lat, z.lon),
                      width: 16,
                      height: 16,
                      child: const DecoratedBox(decoration: BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                    )),
              ]),
            ],
          ),
        ),
        Expanded(child: _buildZonesArea()),
      ],
    );
  }

  Widget _buildZonesArea() {
    switch (_zonesState) {
      case _ZonesState.loading:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.teal),
              SizedBox(height: 12),
              Text('Buscando zonas seguras cercanas…', style: TextStyle(color: AppColors.dim, fontSize: 12.5)),
            ],
          ),
        );
      case _ZonesState.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tenemos tu ubicación, pero no pudimos cargar las zonas seguras cercanas. Revisa tu conexión a internet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.dim),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _loadZones(_position!.latitude, _position!.longitude), child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      case _ZonesState.empty:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No encontramos espacios abiertos catalogados en un radio de 7 km (parques, plazas, canchas o colegios en OpenStreetMap). Puede que tu zona aún no esté mapeada allí.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.dim, fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => _loadZones(_position!.latitude, _position!.longitude), child: const Text('Reintentar')),
              ],
            ),
          ),
        );
      case _ZonesState.ok:
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _zones.length,
          separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 1),
          itemBuilder: (context, i) {
            final z = _zones[i];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(z.name, style: const TextStyle(fontSize: 13.5)),
              subtitle: Text(z.type, style: const TextStyle(fontSize: 11.5, color: AppColors.dim)),
              trailing: Text('${z.distanceKm.toStringAsFixed(1)} km', style: AppTheme.mono(size: 12, color: AppColors.teal)),
            );
          },
        );
    }
  }
}

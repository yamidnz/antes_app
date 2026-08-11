import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
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

class _MapScreenState extends State<MapScreen> {
  final _locationService = LocationService();
  Position? _position;
  List<SafeZone> _zones = [];
  bool _loading = true;
  bool _zonesError = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final ok = await _locationService.ensurePermission();
    if (!ok) {
      setState(() { _loading = false; _error = 'Activa el permiso de ubicación (y el GPS del sistema) para ver zonas seguras cercanas.'; });
      return;
    }

    Position pos;
    try {
      pos = await _locationService.getPreciseLocation(timeout: const Duration(seconds: 20));
    } catch (e) {
      setState(() { _loading = false; _error = 'No pudimos obtener tu ubicación GPS. Verifica que el GPS esté activado y que tengas buena señal (prueba cerca de una ventana o al aire libre).'; });
      return;
    }

    setState(() { _position = pos; });

    try {
      final zones = await _fetchSafeZones(pos.latitude, pos.longitude);
      setState(() { _zones = zones; _loading = false; });
    } catch (e) {
      // Ya tenemos la ubicación: mostramos el mapa igual, solo avisamos
      // que no se pudieron cargar las zonas (probable falta de internet).
      setState(() { _zones = []; _loading = false; _error = null; _zonesError = true; });
    }
  }

  // La distancia real se calcula con Geolocator.distanceBetween (más abajo),
  // que usa una fórmula geodésica correcta — no hace falta reimplementarla.

  // Varios espejos de Overpass: el servidor principal (overpass-api.de) se
  // satura o cae con frecuencia. Si uno falla, probamos el siguiente antes
  // de rendirnos.
  static const _overpassMirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.openstreetmap.ru/api/interpreter',
  ];

  String _buildQuery(double lat, double lon, int radiusM) {
    return '[out:json][timeout:20];'
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

  Future<List<SafeZone>> _fetchSafeZones(double lat, double lon) async {
    // Radio de búsqueda progresivo: si no hay nada catalogado cerca,
    // ampliamos antes de rendirnos.
    for (final radius in [1800, 3500, 6000]) {
      final query = _buildQuery(lat, lon, radius);
      for (final mirror in _overpassMirrors) {
        try {
          final res = await http
              .post(Uri.parse(mirror), body: {'data': query})
              .timeout(const Duration(seconds: 18));
          if (res.statusCode != 200) continue;
          final zones = _parseZones(res.body, lat, lon);
          if (zones.isNotEmpty) return zones.take(10).toList();
        } catch (_) {
          continue; // probamos el siguiente espejo
        }
      }
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zonas seguras', style: AppTheme.display())),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.dim)),
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
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
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
        Expanded(
          child: _zonesError
              ? Center(
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
                        OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : _zones.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No encontramos espacios abiertos catalogados en un radio de 6 km (buscamos parques, plazas, canchas y colegios en OpenStreetMap). Puede que tu zona aún no esté mapeada.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.dim, fontSize: 12.5, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _load, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
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
                ),
        ),
      ],
    );
  }
}

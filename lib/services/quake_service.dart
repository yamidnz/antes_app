import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quake.dart';

/// Trae sismos reales del feed público del USGS y los filtra a un bbox
/// que cubre Colombia continental e insular. Se reutiliza en Inicio y
/// en Actividad para no duplicar la llamada de red ni la lógica de filtro.
class QuakeService {
  static const _feedUrl =
      'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_month.geojson';

  Future<List<Quake>> fetchColombiaQuakes() async {
    final res = await http.get(Uri.parse(_feedUrl)).timeout(const Duration(seconds: 12));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>;
    final quakes = <Quake>[];
    for (final f in features) {
      final geometry = f['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final lon = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final depth = coords.length > 2 ? (coords[2] as num).toDouble() : 0.0;
      // Bbox aproximado de Colombia continental + insular (San Andrés, etc.)
      if (lon > -82 && lon < -66 && lat > -4.5 && lat < 13.5) {
        final props = f['properties'] as Map<String, dynamic>;
        quakes.add(Quake(
          mag: (props['mag'] as num?)?.toDouble() ?? 0,
          place: props['place'] as String? ?? 'Ubicación desconocida',
          time: DateTime.fromMillisecondsSinceEpoch(props['time'] as int),
          lat: lat,
          lon: lon,
          depthKm: depth,
        ));
      }
    }
    quakes.sort((a, b) => b.time.compareTo(a.time));
    return quakes;
  }

  int countLast24h(List<Quake> quakes) {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    return quakes.where((q) => q.time.isAfter(cutoff)).length;
  }
}

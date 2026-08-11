import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../models/quake.dart';
import '../services/compass_utils.dart';
import '../theme/app_theme.dart';

class QuakeDetailScreen extends StatelessWidget {
  final Quake quake;
  const QuakeDetailScreen({super.key, required this.quake});

  Color get _color => quake.mag >= 5 ? AppColors.red : quake.mag >= 4 ? AppColors.amber : AppColors.teal;

  @override
  Widget build(BuildContext context) {
    final center = ll.LatLng(quake.lat, quake.lon);
    return Scaffold(
      appBar: AppBar(title: Text('Detalle del sismo', style: AppTheme.display())),
      body: ListView(
        children: [
          SizedBox(
            height: 260,
            child: FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 7),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'co.antesapp.app',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: center,
                    width: 46,
                    height: 46,
                    child: Icon(Icons.circle, color: _color.withOpacity(0.25), size: 46),
                  ),
                  Marker(
                    point: center,
                    width: 16,
                    height: 16,
                    child: Container(decoration: BoxDecoration(color: _color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quake.place, style: AppTheme.display(size: 19)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _infoChip('${quake.mag.toStringAsFixed(1)}', 'Magnitud', _color),
                    const SizedBox(width: 10),
                    _infoChip('${quake.depthKm.toStringAsFixed(0)} km', 'Profundidad', AppColors.blue),
                  ],
                ),
                const SizedBox(height: 18),
                _row(Icons.schedule, CompassUtils.relativeTime(quake.time)),
                const SizedBox(height: 8),
                _row(Icons.pin_drop_outlined, '${quake.lat.toStringAsFixed(4)}, ${quake.lon.toStringAsFixed(4)}'),
                const SizedBox(height: 8),
                _row(Icons.source_outlined, 'Fuente: ${quake.source}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTheme.mono(size: 22, color: color).copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.dim)),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.dim2),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.dim))),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/quake.dart';
import '../services/alert_settings_repository.dart';
import '../services/background_service.dart';
import '../services/compass_utils.dart';
import '../services/location_service.dart';
import '../services/quake_service.dart';
import '../theme/app_theme.dart';
import 'quake_detail_screen.dart';
import 'report_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final _quakeService = QuakeService();
  final _locationService = LocationService();

  List<Quake>? _quakes;
  Position? _userPos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    // La ubicación es opcional aquí: si no está disponible, igual mostramos
    // la lista, solo sin distancia/dirección.
    try {
      final hasPermission = await _locationService.ensurePermission();
      if (hasPermission) {
        _userPos = await _locationService.getPreciseLocation(timeout: const Duration(seconds: 8));
        await AlertSettingsRepository().saveLastKnownLocation(_userPos!.latitude, _userPos!.longitude);
      }
    } catch (_) {
      _userPos = null;
    }

    try {
      final quakes = await _quakeService.fetchColombiaQuakes();
      setState(() { _quakes = quakes; _loading = false; });
      // Dispara notificaciones al toque si detecta sismos nuevos, sin
      // esperar al próximo ciclo de 15 min en segundo plano.
      checkForNewQuakesAndNotify().catchError((_) => 0);
    } catch (_) {
      setState(() { _quakes = []; _loading = false; });
    }
  }

  Color _magColor(double mag) => mag >= 5 ? AppColors.red : mag >= 4 ? AppColors.amber : AppColors.teal;

  @override
  Widget build(BuildContext context) {
    final count24h = _quakes == null ? null : _quakeService.countLast24h(_quakes!);

    return Scaffold(
      appBar: AppBar(
        title: Text('Actividad sísmica', style: AppTheme.display()),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Reportar un sismo que sentiste',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: const Color(0xFF241900),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen())),
        icon: const Icon(Icons.vibration),
        label: const Text('¡Sentí un sismo!'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        backgroundColor: AppColors.card,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsHeader(count24h),
                  const SizedBox(height: 16),
                  if (_quakes == null || _quakes!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Sin sismos ≥ M2.5 registrados por USGS en Colombia el último mes, o sin conexión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.dim),
                      ),
                    )
                  else
                    ..._quakes!.map(_buildQuakeCard),
                  const SizedBox(height: 70),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsHeader(int? count24h) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            value: count24h?.toString() ?? '—',
            label: 'Sismos M≥2.5\núltimas 24 h',
            color: AppColors.teal,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            value: (_quakes?.length ?? 0).toString(),
            label: 'Registrados en\nel último mes',
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }

  Widget _statCard({required String value, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.mono(size: 26, color: color).copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.dim, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildQuakeCard(Quake q) {
    final color = _magColor(q.mag);
    String? distLabel;
    if (_userPos != null) {
      final dist = CompassUtils.distanceKm(_userPos!.latitude, _userPos!.longitude, q.lat, q.lon);
      final bearing = CompassUtils.bearing(_userPos!.latitude, _userPos!.longitude, q.lat, q.lon);
      distLabel = '${dist.toStringAsFixed(0)} km de tu ubicación (${CompassUtils.label(bearing)} ${CompassUtils.arrow(bearing)})';
    }

    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuakeDetailScreen(quake: q))),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 3, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)))),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.place, style: AppTheme.display(size: 14, w: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(q.mag.toStringAsFixed(1), style: AppTheme.mono(size: 26, color: color).copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('mag.', style: AppTheme.mono(size: 11, color: AppColors.dim)),
                    ),
                    const Spacer(),
                    const Icon(Icons.south, size: 13, color: AppColors.dim2),
                    Text(' ${q.depthKm.toStringAsFixed(0)} km prof.', style: AppTheme.mono(size: 11.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.schedule, size: 13, color: AppColors.dim2),
                  const SizedBox(width: 5),
                  Text(CompassUtils.relativeTime(q.time), style: const TextStyle(fontSize: 12, color: AppColors.dim)),
                ]),
                if (distLabel != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.explore_outlined, size: 13, color: AppColors.dim2),
                    const SizedBox(width: 5),
                    Expanded(child: Text(distLabel, style: const TextStyle(fontSize: 12, color: AppColors.dim))),
                  ]),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.bgElevated, borderRadius: BorderRadius.circular(6)),
                    child: Text('Fuente: ${q.source}', style: AppTheme.mono(size: 10, color: AppColors.dim2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

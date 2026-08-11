import 'package:flutter/material.dart';
import '../services/quake_service.dart';
import '../models/quake.dart';
import '../services/compass_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/wave_header.dart';
import 'report_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onGoMap;
  final VoidCallback onGoTips;
  final VoidCallback onGoSos;
  final VoidCallback onGoActivity;
  const HomeScreen({
    super.key,
    required this.onGoMap,
    required this.onGoTips,
    required this.onGoSos,
    required this.onGoActivity,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _quakeService = QuakeService();
  List<Quake>? _quakes;

  @override
  void initState() {
    super.initState();
    _quakeService.fetchColombiaQuakes().then((q) {
      if (mounted) setState(() => _quakes = q);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final count24h = _quakes == null ? null : _quakeService.countLast24h(_quakes!);
    final last = (_quakes != null && _quakes!.isNotEmpty) ? _quakes!.first : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ANTES', style: AppTheme.display(size: 24, w: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('MONITOREANDO', style: AppTheme.mono(size: 10.5, color: AppColors.teal)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const WaveHeader(),
            const SizedBox(height: 18),

            // ---- Estadísticas reales (USGS), no inventadas ----
            Row(
              children: [
                Expanded(child: _statCard(count24h?.toString() ?? '—', 'Sismos M≥2.5\nColombia · 24 h', AppColors.teal, onTap: widget.onGoActivity)),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    last != null ? '${last.mag.toStringAsFixed(1)}' : '—',
                    last != null ? 'Último: ${CompassUtils.relativeTime(last.time)}' : 'Último sismo\nregistrado',
                    AppColors.blue,
                    onTap: widget.onGoActivity,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ---- Accesos rápidos, estilo "pill", inspirados en apps de referencia ----
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _pillButton('¡Sentí un sismo!', Icons.vibration, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportScreen()))),
                _pillButton('Zonas seguras', Icons.map_outlined, widget.onGoMap),
                _pillButton('Guía de acción', Icons.checklist_outlined, widget.onGoTips),
                _pillButton('Actividad', Icons.show_chart, widget.onGoActivity),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.card, Color(0xFF16202B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RED COMUNITARIA DE SENSORES', style: AppTheme.mono(size: 10.5, color: AppColors.dim2)),
                  const SizedBox(height: 8),
                  Text('Segundos de aviso pueden salvar vidas.', style: AppTheme.display(size: 21, w: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'ANTES detecta sismos reales cerca de Colombia y te avisa. Si algo pasa, tu botón SOS envía tu ubicación exacta en segundos.',
                    style: TextStyle(fontSize: 13.5, color: AppColors.dim, height: 1.55),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: widget.onGoSos,
                      icon: const Icon(Icons.sos),
                      label: const Text('Configurar / usar SOS'),
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

  Widget _statCard(String value, String label, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTheme.mono(size: 24, color: color).copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.dim, height: 1.3)),
          ],
        ),
      ),
    );
  }

  Widget _pillButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(30), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/quake_report.dart';
import '../services/location_service.dart';
import '../services/reports_repository.dart';
import '../services/compass_utils.dart';
import '../theme/app_theme.dart';

class _MmiLevel {
  final int level;
  final String roman;
  final String title;
  final String description;
  final Color color;
  _MmiLevel(this.level, this.roman, this.title, this.description, this.color);
}

// Escala de Mercalli Modificada (MMI) — descripciones estándar, no inventadas.
final _levels = [
  _MmiLevel(2, 'II', 'Apenas percibido', 'Sentido solo por personas en reposo, especialmente en pisos altos.', AppColors.dim2),
  _MmiLevel(3, 'III', 'Vibración leve', 'Parecido al paso de un camión liviano. Puede no reconocerse como sismo.', AppColors.blue),
  _MmiLevel(4, 'IV', 'Vibración de ventanas', 'Platos, ventanas y puertas vibran. Sensación como de un camión pesado.', AppColors.teal),
  _MmiLevel(5, 'V', 'Caída de objetos', 'Sentido por casi todos. Se rompen platos y ventanas. Objetos inestables se vuelcan.', const Color(0xFF7FC93B)),
  _MmiLevel(6, 'VI', 'Daños leves', 'Sentido por todos. Muebles se mueven. Caen objetos de estantes. Grietas leves.', AppColors.amber),
  _MmiLevel(7, 'VII', 'Daños moderados', 'Difícil mantenerse de pie. Daños notables en construcciones débiles.', const Color(0xFFE8752B)),
  _MmiLevel(8, 'VIII', 'Daños considerables', 'Daños parciales en estructuras comunes. Caída de chimeneas y muros.', AppColors.red),
];

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _locationService = LocationService();
  final _reportsRepo = ReportsRepository();
  int? _selected;
  bool _sending = false;
  List<QuakeReport> _myReports = [];

  @override
  void initState() {
    super.initState();
    _loadMyReports();
  }

  Future<void> _loadMyReports() async {
    final list = await _reportsRepo.getAll();
    if (mounted) setState(() => _myReports = list);
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    setState(() => _sending = true);

    final level = _levels.firstWhere((l) => l.level == _selected);
    double? lat, lon;
    try {
      if (await _locationService.ensurePermission()) {
        final pos = await _locationService.getPreciseLocation(timeout: const Duration(seconds: 8));
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (_) {}

    final report = QuakeReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      mmiLevel: level.level,
      label: level.title,
      time: DateTime.now(),
      lat: lat,
      lon: lon,
    );

    // Guardamos siempre localmente, aunque falle el envío a la red.
    await _reportsRepo.add(report);

    // TODO(fase 2): endpoint real de agregación comunitaria. Por ahora es
    // un stub — el conteo "reportes en tu zona" necesita un backend que
    // agregue reportes de todos los usuarios, no solo el tuyo.
    try {
      await http
          .post(
            Uri.parse('https://api.antesapp.co/v1/reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mmi': level.level,
              'lat': lat,
              'lon': lon,
              'timestamp': report.time.toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // Sin conexión con la red comunitaria: no es crítico, ya quedó
      // guardado localmente.
    }

    await _loadMyReports();
    if (!mounted) return;
    setState(() { _sending = false; _selected = null; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gracias, tu reporte quedó registrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('¡Sentí un sismo!', style: AppTheme.display())),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'Ayuda a otros usuarios de ANTES eligiendo qué tan fuerte sentiste el movimiento. '
            'Tu reporte queda guardado en tu historial y, cuando la red comunitaria esté activa, '
            'se suma a un mapa colectivo de intensidad.',
            style: TextStyle(fontSize: 12.5, color: AppColors.dim, height: 1.5),
          ),
          const SizedBox(height: 18),
          ..._levels.map((l) => _buildLevelTile(l)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selected == null || _sending) ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enviar reporte'),
            ),
          ),
          if (_myReports.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('Tu historial de reportes', style: AppTheme.display(size: 15)),
            const SizedBox(height: 10),
            ..._myReports.take(10).map((r) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.line)),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _levels.firstWhere((l) => l.level == r.mmiLevel).color.withOpacity(0.18), borderRadius: BorderRadius.circular(8)),
                        child: Text(_levels.firstWhere((l) => l.level == r.mmiLevel).roman, style: AppTheme.mono(size: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.label, style: const TextStyle(fontSize: 12.5)),
                            Text(CompassUtils.relativeTime(r.time), style: const TextStyle(fontSize: 10.5, color: AppColors.dim)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildLevelTile(_MmiLevel l) {
    final selected = _selected == l.level;
    return InkWell(
      onTap: () => setState(() => _selected = l.level),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? l.color.withOpacity(0.14) : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? l.color : AppColors.line, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: l.color, borderRadius: BorderRadius.circular(9)),
              child: Text(l.roman, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.title, style: AppTheme.display(size: 13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(l.description, style: const TextStyle(fontSize: 11.5, color: AppColors.dim, height: 1.35)),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: l.color, size: 20),
          ],
        ),
      ),
    );
  }
}

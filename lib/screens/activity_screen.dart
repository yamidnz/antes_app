import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';

class _Quake {
  final double mag;
  final String place;
  final DateTime time;
  _Quake(this.mag, this.place, this.time);
}

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<_Quake>? _quakes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_month.geojson'))
          .timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>;
      final quakes = <_Quake>[];
      for (final f in features) {
        final coords = f['geometry']['coordinates'] as List<dynamic>;
        final lon = coords[0] as num;
        final lat = coords[1] as num;
        // Bbox aproximado de Colombia continental + insular.
        if (lon > -82 && lon < -66 && lat > -4.5 && lat < 13.5) {
          final props = f['properties'] as Map<String, dynamic>;
          quakes.add(_Quake(
            (props['mag'] as num?)?.toDouble() ?? 0,
            props['place'] as String? ?? 'Ubicación desconocida',
            DateTime.fromMillisecondsSinceEpoch(props['time'] as int),
          ));
        }
      }
      quakes.sort((a, b) => b.time.compareTo(a.time));
      setState(() { _quakes = quakes.take(12).toList(); _loading = false; });
    } catch (_) {
      setState(() { _quakes = []; _loading = false; });
    }
  }

  Color _magColor(double mag) => mag >= 5 ? AppColors.red : mag >= 4 ? AppColors.amber : AppColors.teal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Actividad sísmica', style: AppTheme.display())),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.teal,
        backgroundColor: AppColors.card,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
            : (_quakes == null || _quakes!.isEmpty)
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(40),
                      child: Text('Sin sismos ≥ M2.5 registrados por USGS en Colombia el último mes, o sin conexión.',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.dim)),
                    ),
                  ])
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _quakes!.length,
                    separatorBuilder: (_, __) => const Divider(color: AppColors.line, height: 1),
                    itemBuilder: (context, i) {
                      final q = _quakes![i];
                      final color = _magColor(q.mag);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                          child: Text(q.mag.toStringAsFixed(1), style: AppTheme.mono(size: 14, color: color)),
                        ),
                        title: Text(q.place, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          '${q.time.day}/${q.time.month} · ${q.time.hour.toString().padLeft(2, '0')}:${q.time.minute.toString().padLeft(2, '0')}',
                          style: AppTheme.mono(size: 11),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/quake_report.dart';

/// Historial de "sentí un sismo" del propio usuario, guardado en el
/// dispositivo. Es honesto mostrar solo lo que el usuario mismo reportó,
/// en vez de inventar un contador global sin backend real detrás.
class ReportsRepository {
  static const _key = 'antes_quake_reports';

  Future<List<QuakeReport>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => QuakeReport.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  Future<void> add(QuakeReport report) async {
    final all = await getAll();
    all.insert(0, report);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all.map((r) => r.toJson()).toList()));
  }
}

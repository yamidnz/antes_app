import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Todo lo que gobierna cuándo y a quién le llega una notificación de
/// sismo. Vive en SharedPreferences porque el chequeo en segundo plano
/// (background_service.dart) corre en un isolate aparte y necesita poder
/// leer esto sin depender del estado en memoria de la app.
class AlertSettingsRepository {
  static const _radiusKey = 'antes_alert_radius_km';
  static const _lastLatKey = 'antes_last_lat';
  static const _lastLonKey = 'antes_last_lon';
  static const _seenIdsKey = 'antes_seen_quake_ids';
  static const _notificationsEnabledKey = 'antes_notifications_enabled';

  static const defaultRadiusKm = 300.0;

  Future<double> getRadiusKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_radiusKey) ?? defaultRadiusKm;
  }

  Future<void> setRadiusKm(double km) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_radiusKey, km);
  }

  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
  }

  /// Cada vez que la app obtiene un GPS fresco en primer plano, lo guardamos
  /// aquí para que la tarea en segundo plano tenga un punto de referencia
  /// razonable sin tener que pedir permisos de ubicación "always".
  Future<void> saveLastKnownLocation(double lat, double lon) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lastLatKey, lat);
    await prefs.setDouble(_lastLonKey, lon);
  }

  Future<(double, double)?> getLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_lastLatKey);
    final lon = prefs.getDouble(_lastLonKey);
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }

  Future<Set<String>> getSeenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_seenIdsKey);
    if (raw == null) return {};
    return Set<String>.from(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> saveSeenIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    // Nos quedamos solo con los últimos 200 para no crecer sin límite.
    final list = ids.toList();
    final trimmed = list.length > 200 ? list.sublist(list.length - 200) : list;
    await prefs.setString(_seenIdsKey, jsonEncode(trimmed));
  }
}

import 'package:geolocator/geolocator.dart';

/// Convierte un rumbo en grados (0-360, resultado de bearingBetween) a una
/// abreviatura de brújula de 8 puntos con su flecha, como en las apps
/// sismológicas de referencia (ej. "SE ↘").
class CompassUtils {
  static const _labels = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
  static const _arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];

  static String label(double bearingDeg) {
    final normalized = (bearingDeg + 360) % 360;
    final index = (((normalized + 22.5) / 45).floor()) % 8;
    return _labels[index];
  }

  static String arrow(double bearingDeg) {
    final normalized = (bearingDeg + 360) % 360;
    final index = (((normalized + 22.5) / 45).floor()) % 8;
    return _arrows[index];
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }

  static double bearing(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  /// "Hace 5 min", "Hace 3 h", "Hace 2 días" — igual que en apps sismológicas.
  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} día${diff.inDays == 1 ? '' : 's'}';
  }
}

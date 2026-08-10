import 'package:geolocator/geolocator.dart';

/// Encapsula el acceso al GPS del dispositivo.
/// Pide siempre la mayor precisión posible porque, en un SOS, unos metros
/// de error pueden ser la diferencia entre encontrar a alguien rápido o no.
class LocationService {
  Future<bool> ensurePermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Obtiene la posición actual con alta precisión.
  /// Si tarda más de [timeout], cae a la última posición conocida para no
  /// dejar a alguien en una emergencia esperando indefinidamente al GPS.
  Future<Position> getPreciseLocation({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(timeout);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }
}

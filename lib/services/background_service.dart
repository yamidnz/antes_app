import 'alert_settings_repository.dart';
import 'compass_utils.dart';
import 'notification_service.dart';
import 'quake_service.dart';

/// NOTA: originalmente esto corría también en segundo plano vía
/// `workmanager`, pero ese paquete usa una integración con Android que
/// las versiones recientes de Flutter ya no soportan (falla la
/// compilación). Se quitó para no depender de un plugin roto — hoy este
/// chequeo se dispara en primer plano, cada vez que se abre Inicio o
/// Actividad. Un aviso real con la app cerrada requeriría notificaciones
/// push desde un backend (Firebase Cloud Messaging) — ver Fase 2 de la
/// especificación técnica.
Future<int> checkForNewQuakesAndNotify() async {
  final settings = AlertSettingsRepository();
  final enabled = await settings.getNotificationsEnabled();
  if (!enabled) return 0;

  final radiusKm = await settings.getRadiusKm();
  final lastLocation = await settings.getLastKnownLocation();
  final seenIds = await settings.getSeenIds();

  final quakeService = QuakeService();
  final quakes = await quakeService.fetchColombiaQuakes();

  final notificationService = NotificationService();

  var notified = 0;
  final newSeenIds = Set<String>.from(seenIds);
  var isFirstRun = seenIds.isEmpty;

  for (final q in quakes) {
    if (seenIds.contains(q.id)) continue;
    newSeenIds.add(q.id);

    // La primera vez que corre (sin historial de sismos "vistos"), no
    // notificamos toda la lista de golpe — solo dejamos el marcador y
    // notificamos desde el próximo chequeo en adelante.
    if (isFirstRun) continue;

    double? distanceKm;
    if (lastLocation != null) {
      distanceKm = CompassUtils.distanceKm(lastLocation.$1, lastLocation.$2, q.lat, q.lon);
      if (distanceKm > radiusKm) continue; // fuera del radio que pidió el usuario
    } else if (q.mag < 4.0) {
      continue; // sin ubicación guardada, solo avisamos de sismos relevantes
    }

    await notificationService.showQuakeAlert(q, distanceKm: distanceKm);
    notified++;
  }

  await settings.saveSeenIds(newSeenIds);
  return notified;
}

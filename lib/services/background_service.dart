import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'alert_settings_repository.dart';
import 'compass_utils.dart';
import 'notification_service.dart';
import 'quake_service.dart';

const backgroundTaskName = 'antes_check_quakes';

/// Debe ser una función de nivel superior (no un método de clase) para que
/// Android pueda invocarla en un isolate aparte cuando la app no está
/// abierta. El @pragma es obligatorio para que sobreviva a la minificación
/// de código en compilaciones release.
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await checkForNewQuakesAndNotify();
    } catch (_) {
      // Si falla (sin internet, feed caído, etc.) simplemente reintentamos
      // en el siguiente ciclo — no hacemos que la tarea falle en bucle.
    }
    return Future.value(true);
  });
}

/// La lógica real: se usa tanto desde la tarea en segundo plano como desde
/// la app en primer plano (al abrir Actividad/Inicio), para que una alerta
/// nueva se notifique apenas se detecta, sin esperar al próximo ciclo.
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
  await notificationService.init(onTapPayload: (_) {}); // no-op aquí: la navegación real la maneja main.dart

  var notified = 0;
  final newSeenIds = Set<String>.from(seenIds);

  for (final q in quakes) {
    if (seenIds.contains(q.id)) continue;
    newSeenIds.add(q.id);

    double? distanceKm;
    if (lastLocation != null) {
      distanceKm = CompassUtils.distanceKm(lastLocation.$1, lastLocation.$2, q.lat, q.lon);
      if (distanceKm > radiusKm) continue; // fuera del radio que pidió el usuario
    }
    // Sin ubicación guardada: solo notificamos sismos con magnitud
    // relevante para no saturar con sismos menores de todo el país.
    if (lastLocation == null && q.mag < 4.0) continue;

    await notificationService.showQuakeAlert(q, distanceKm: distanceKm);
    notified++;
  }

  await settings.saveSeenIds(newSeenIds);
  return notified;
}

class BackgroundService {
  Future<void> initializeAndSchedule() async {
    await Workmanager().initialize(backgroundCallbackDispatcher);
    await Workmanager().registerPeriodicTask(
      'antes-quake-poll',
      backgroundTaskName,
      // 15 minutos es el mínimo que permite Android para tareas periódicas;
      // Android puede espaciarlas más según el estado de batería del equipo.
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}

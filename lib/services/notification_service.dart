import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/quake.dart';

/// Encapsula flutter_local_notifications. Cada notificación de sismo lleva
/// en el payload los datos del sismo (JSON), para que al tocarla podamos
/// abrir directamente la vista previa en el mapa (QuakeDetailScreen) sin
/// tener que volver a consultar el feed.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  static const _channelId = 'antes_quake_alerts';

  Future<void> init({
    required void Function(String payload) onTapPayload,
  }) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: darwinSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null) onTapPayload(response.payload!);
      },
    );

    const channel = AndroidNotificationChannel(
      _channelId,
      'Alertas sísmicas',
      description: 'Avisos de sismos detectados cerca del radio que configuraste',
      importance: Importance.max,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Si la app fue abierta tocando una notificación mientras estaba
  /// cerrada, esto trae ese payload para navegar apenas arranque.
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }

  Future<bool> requestPermission() async {
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? false;
    }
    final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosImpl != null) {
      final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    return true;
  }

  Future<void> showQuakeAlert(Quake q, {double? distanceKm}) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Alertas sísmicas',
        channelDescription: 'Avisos de sismos detectados cerca del radio que configuraste',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(
          distanceKm != null
              ? 'Profundidad ${q.depthKm.toStringAsFixed(0)} km · a ${distanceKm.toStringAsFixed(0)} km de tu ubicación guardada.'
              : 'Profundidad ${q.depthKm.toStringAsFixed(0)} km.',
        ),
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    final payload = jsonEncode({
      'id': q.id,
      'mag': q.mag,
      'place': q.place,
      'time': q.time.toIso8601String(),
      'lat': q.lat,
      'lon': q.lon,
      'depth': q.depthKm,
    });

    await _plugin.show(
      q.id.hashCode,
      'Sismo M${q.mag.toStringAsFixed(1)} · ${q.place}',
      distanceKm != null
          ? 'A ${distanceKm.toStringAsFixed(0)} km de tu ubicación. Toca para ver el mapa.'
          : 'Toca para ver el mapa y más detalles.',
      details,
      payload: payload,
    );
  }

  /// Notificación de prueba, usada por el simulador de alerta en Ajustes.
  Future<void> showTestAlert() async {
    final fakeQuake = Quake(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      mag: 6.1,
      place: 'Simulacro — no es un sismo real',
      time: DateTime.now(),
      lat: 4.6097,
      lon: -74.0817,
      depthKm: 35,
    );
    await showQuakeAlert(fakeQuake, distanceKm: 42);
  }
}

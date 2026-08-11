import 'package:flutter/material.dart';
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/alert_settings_repository.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _alertSettings = AlertSettingsRepository();

  bool? _locationGranted;
  bool? _locationServiceOn;
  bool? _notificationGranted;
  double _radiusKm = AlertSettingsRepository.defaultRadiusKm;
  bool _notificationsEnabled = true;
  bool _testSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si el usuario vuelve de los Ajustes del sistema, refrescamos el
    // estado de los permisos automáticamente.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final locPermission = await Geolocator.checkPermission();
    final locGranted = locPermission == LocationPermission.always || locPermission == LocationPermission.whileInUse;
    final locServiceOn = await Geolocator.isLocationServiceEnabled();
    final notifStatus = await Permission.notification.status;
    final radius = await _alertSettings.getRadiusKm();
    final notifEnabled = await _alertSettings.getNotificationsEnabled();

    if (!mounted) return;
    setState(() {
      _locationGranted = locGranted;
      _locationServiceOn = locServiceOn;
      _notificationGranted = notifStatus.isGranted;
      _radiusKm = radius;
      _notificationsEnabled = notifEnabled;
    });
  }

  Future<void> _fixLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
      _refresh();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  Future<void> _fixNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await NotificationService().requestPermission();
      _refresh();
    } else {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }

  Future<void> _sendTestAlert() async {
    setState(() => _testSending = true);
    await NotificationService().requestPermission();
    await NotificationService().showTestAlert();
    if (!mounted) return;
    setState(() => _testSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación de prueba enviada — revisa tu barra de notificaciones.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ajustes y permisos', style: AppTheme.display())),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('CONFIGURACIÓN DEL DISPOSITIVO', style: AppTheme.mono(size: 10.5, color: AppColors.dim2)),
          const SizedBox(height: 10),
          _permRow(
            title: 'Permiso de ubicación',
            ok: _locationGranted,
            subtitleOk: 'Concedido',
            subtitleBad: 'No concedido — necesario para el mapa, la actividad y el SOS',
            onTap: _fixLocationPermission,
          ),
          _permRow(
            title: 'GPS / servicios de ubicación',
            ok: _locationServiceOn,
            subtitleOk: 'Activado',
            subtitleBad: 'Desactivado a nivel de sistema',
            onTap: () => Geolocator.openLocationSettings(),
          ),
          _permRow(
            title: 'Permiso de notificaciones',
            ok: _notificationGranted,
            subtitleOk: 'Concedido',
            subtitleBad: 'No concedido — no recibirás alertas en la barra de notificaciones',
            onTap: _fixNotificationPermission,
          ),
          _actionRow(
            title: 'Optimización de batería',
            subtitle: 'Recomendado: excluye ANTES de la optimización para que las alertas en segundo plano no se detengan',
            onTap: () => AppSettings.openAppSettings(type: AppSettingsType.batteryOptimization),
          ),

          const SizedBox(height: 28),
          Text('ALERTAS AUTOMÁTICAS', style: AppTheme.mono(size: 10.5, color: AppColors.dim2)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Recibir notificaciones de sismos', style: AppTheme.display(size: 13.5, w: FontWeight.w600))),
                    Switch(
                      value: _notificationsEnabled,
                      activeColor: AppColors.teal,
                      onChanged: (v) async {
                        await _alertSettings.setNotificationsEnabled(v);
                        setState(() => _notificationsEnabled = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'ANTES revisa el feed sísmico cada vez que abres la app (Inicio o Actividad) y te avisa si hay un sismo dentro del radio que definas. No es una alerta instantánea de segundos ni funciona con la app cerrada — eso requiere una red de sensores dedicada o notificaciones push desde un servidor, que están en el roadmap.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.dim, height: 1.5),
                ),
                const SizedBox(height: 16),
                Text('Avisarme de sismos dentro de: ${_radiusKm.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 13)),
                Slider(
                  value: _radiusKm,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: AppColors.teal,
                  label: '${_radiusKm.toStringAsFixed(0)} km',
                  onChanged: (v) => setState(() => _radiusKm = v),
                  onChangeEnd: (v) => _alertSettings.setRadiusKm(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testSending ? null : _sendTestAlert,
              icon: _testSending
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.notifications_active_outlined),
              label: const Text('Simular una alerta ahora'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Envía una notificación de prueba real a tu barra de notificaciones para confirmar que los permisos están bien configurados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.dim),
          ),
        ],
      ),
    );
  }

  Widget _permRow({
    required String title,
    required bool? ok,
    required String subtitleOk,
    required String subtitleBad,
    required VoidCallback onTap,
  }) {
    final color = ok == null ? AppColors.dim2 : (ok ? AppColors.teal : AppColors.red);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Icon(ok == null ? Icons.help_outline : (ok ? Icons.check_circle : Icons.error_outline), color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.display(size: 13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(ok == true ? subtitleOk : subtitleBad, style: TextStyle(fontSize: 11.5, color: color)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.dim2),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            const Icon(Icons.battery_charging_full, color: AppColors.blue, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.display(size: 13.5, w: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.dim, height: 1.4)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.dim2),
          ],
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'models/quake.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/quake_detail_screen.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AntesApp());
}

class AntesApp extends StatefulWidget {
  const AntesApp({super.key});
  @override
  State<AntesApp> createState() => _AntesAppState();
}

class _AntesAppState extends State<AntesApp> {
  @override
  void initState() {
    super.initState();
    _initBackgroundSystems();
  }

  Future<void> _initBackgroundSystems() async {
    await NotificationService().init(onTapPayload: _openQuakeFromPayload);

    // Si la app se abrió tocando una notificación mientras estaba cerrada.
    final launchPayload = await NotificationService().getLaunchPayload();
    if (launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openQuakeFromPayload(launchPayload));
    }

    await NotificationService().requestPermission();

    // Sin background real (ver nota en background_service.dart): revisamos
    // sismos nuevos aquí, al arrancar la app.
    checkForNewQuakesAndNotify().catchError((_) => 0);
  }

  void _openQuakeFromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final quake = Quake(
        id: data['id'] as String,
        mag: (data['mag'] as num).toDouble(),
        place: data['place'] as String,
        time: DateTime.parse(data['time'] as String),
        lat: (data['lat'] as num).toDouble(),
        lon: (data['lon'] as num).toDouble(),
        depthKm: (data['depth'] as num).toDouble(),
      );
      navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => QuakeDetailScreen(quake: quake)));
    } catch (_) {
      // Payload inválido o de una versión anterior: lo ignoramos en vez de
      // hacer fallar la navegación de la app.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANTES',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      navigatorKey: navigatorKey,
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});
  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  void _goTo(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onGoMap: () => _goTo(1),
        onGoTips: () => _goTo(2),
        onGoSos: () => _goTo(4),
        onGoActivity: () => _goTo(3),
      ),
      const MapScreen(),
      const TipsScreen(),
      const ActivityScreen(),
      const SosScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goTo,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_outlined), activeIcon: Icon(Icons.checklist), label: 'Consejos'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Actividad'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'SOS'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

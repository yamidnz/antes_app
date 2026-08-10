import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/tips_screen.dart';
import 'screens/activity_screen.dart';
import 'screens/sos_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const AntesApp());
}

class AntesApp extends StatelessWidget {
  const AntesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANTES',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
      ),
      const MapScreen(),
      const TipsScreen(),
      const ActivityScreen(),
      const SosScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _goTo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist_outlined), activeIcon: Icon(Icons.checklist), label: 'Consejos'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Actividad'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'SOS'),
        ],
      ),
    );
  }
}

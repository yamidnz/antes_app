import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/wave_header.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onGoMap;
  final VoidCallback onGoTips;
  final VoidCallback onGoSos;
  const HomeScreen({super.key, required this.onGoMap, required this.onGoTips, required this.onGoSos});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ANTES', style: AppTheme.display(size: 24, w: FontWeight.w700)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('MONITOREANDO', style: AppTheme.mono(size: 10.5, color: AppColors.teal)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const WaveHeader(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.card, Color(0xFF16202B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RED COMUNITARIA DE SENSORES', style: AppTheme.mono(size: 10.5, color: AppColors.dim2)),
                  const SizedBox(height: 8),
                  Text('Segundos de aviso pueden salvar vidas.', style: AppTheme.display(size: 21, w: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    'ANTES detecta las primeras ondas de un sismo y te avisa antes de que lleguen las ondas destructivas. Si algo pasa, tu botón SOS envía tu ubicación exacta en segundos.',
                    style: TextStyle(fontSize: 13.5, color: AppColors.dim, height: 1.55),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.red, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: onGoSos,
                      icon: const Icon(Icons.sos),
                      label: const Text('Configurar / usar SOS'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _quickCard(
              icon: Icons.map_outlined,
              title: 'Zonas seguras cercanas',
              body: 'Ubica en segundos el punto de encuentro o espacio abierto más cercano a ti.',
              onTap: onGoMap,
            ),
            const SizedBox(height: 12),
            _quickCard(
              icon: Icons.checklist_outlined,
              title: '¿Sabes qué hacer?',
              body: 'Guía rápida antes, durante y después de un sismo, para Colombia.',
              onTap: onGoTips,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({required IconData icon, required String title, required String body, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Row(
          children: [
            Icon(icon, color: AppColors.teal),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.display(size: 14.5)),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(fontSize: 12.5, color: AppColors.dim, height: 1.4)),
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

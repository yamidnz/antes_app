import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _TipSection {
  final String title;
  final Color color;
  final List<String> items;
  _TipSection(this.title, this.color, this.items);
}

final _sections = [
  _TipSection('Antes del sismo', AppColors.amber, [
    'Identifica zonas seguras en tu casa: bajo mesas firmes, junto a columnas, lejos de ventanas.',
    'Define un punto de encuentro familiar fuera del edificio.',
    'Ten un kit de emergencia: agua, linterna, radio, botiquín, copias de documentos.',
    'Verifica que tu edificio cumpla la norma NSR-10 de construcción sismorresistente.',
    'Configura tus contactos de confianza en la sección SOS de esta app.',
  ]),
  _TipSection('Durante el sismo', AppColors.red, [
    'Agáchate, cúbrete y agárrate — bajo un mueble resistente.',
    'No uses ascensores ni corras hacia las escaleras durante el movimiento.',
    'Si estás en la calle, aléjate de fachadas, postes y cables eléctricos.',
    'Si conduces, detente en un lugar despejado y permanece dentro del vehículo.',
    'Si estás en la costa Pacífica o Caribe, prepárate para evacuar por posible tsunami tras el sismo.',
  ]),
  _TipSection('Después del sismo', AppColors.teal, [
    'Sal con calma hacia tu punto de encuentro, usando las escaleras.',
    'No regreses a edificios dañados sin autorización de las autoridades.',
    'Revisa fugas de gas y daños eléctricos antes de usar interruptores.',
    'Mantente atento a réplicas — pueden ocurrir minutos u horas después.',
    'Si necesitas ayuda inmediata, usa el botón SOS para enviar tu ubicación exacta.',
  ]),
];

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});
  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Guía de acción', style: AppTheme.display())),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        itemBuilder: (context, i) {
          final s = _sections[i];
          final isOpen = _open == i;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
            child: Column(
              children: [
                InkWell(
                  onTap: () => setState(() => _open = isOpen ? -1 : i),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.title, style: AppTheme.display(size: 15))),
                        Icon(isOpen ? Icons.remove : Icons.add, color: AppColors.dim, size: 20),
                      ],
                    ),
                  ),
                ),
                if (isOpen)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: s.items
                          .map((t) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  ', style: TextStyle(color: AppColors.dim)),
                                    Expanded(child: Text(t, style: const TextStyle(fontSize: 13, color: AppColors.dim, height: 1.5))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

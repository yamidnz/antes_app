import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/emergency_contact.dart';
import '../services/contacts_repository.dart';
import '../services/location_service.dart';
import '../services/sos_service.dart';
import '../theme/app_theme.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

enum _SosStage { idle, holding, locating, sending, done, error }

class _SosScreenState extends State<SosScreen> with SingleTickerProviderStateMixin {
  final _contactsRepo = ContactsRepository();
  final _locationService = LocationService();
  final _sosService = SosService();

  late AnimationController _holdController;
  _SosStage _stage = _SosStage.idle;
  List<EmergencyContact> _contacts = [];
  bool _communityOptIn = false;
  SosResult? _result;
  String? _errorText;

  static const _holdDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _startSos();
      });
    _loadContacts();
    _loadCommunitySetting();
  }

  Future<void> _loadContacts() async {
    final list = await _contactsRepo.getAll();
    if (mounted) setState(() => _contacts = list);
  }

  Future<void> _loadCommunitySetting() async {
    final v = await _sosService.isCommunityOptIn();
    if (mounted) setState(() => _communityOptIn = v);
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  Future<void> _startSos() async {
    if (_contacts.isEmpty) {
      _showNeedContactsSheet();
      _resetHold();
      return;
    }

    final canSend = await _sosService.canSendNow();
    if (!canSend) {
      setState(() {
        _stage = _SosStage.error;
        _errorText = 'Ya enviaste un SOS hace menos de un minuto. Espera un momento antes de enviar otro.';
      });
      return;
    }

    setState(() => _stage = _SosStage.locating);

    final hasPermission = await _locationService.ensurePermission();
    if (!hasPermission) {
      setState(() {
        _stage = _SosStage.error;
        _errorText = 'ANTES necesita acceso a tu ubicación para enviar tus coordenadas exactas. Actívalo en Ajustes del sistema.';
      });
      return;
    }

    Position position;
    try {
      position = await _locationService.getPreciseLocation();
    } catch (_) {
      setState(() {
        _stage = _SosStage.error;
        _errorText = 'No pudimos obtener tu ubicación. Verifica que el GPS esté activado.';
      });
      return;
    }

    setState(() => _stage = _SosStage.sending);

    final result = await _sosService.fireSos(position: position, contacts: _contacts);

    if (!mounted) return;
    setState(() {
      _result = result;
      _stage = _SosStage.done;
    });
  }

  void _resetHold() {
    _holdController.reset();
    if (_stage == _SosStage.holding) setState(() => _stage = _SosStage.idle);
  }

  void _resetAll() {
    _holdController.reset();
    setState(() {
      _stage = _SosStage.idle;
      _result = null;
      _errorText = null;
    });
  }

  void _showNeedContactsSheet() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primero agrega al menos un contacto de confianza abajo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SOS', style: AppTheme.display())),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSosCard(),
            const SizedBox(height: 24),
            _buildCommunityToggle(),
            const SizedBox(height: 20),
            _buildContactsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSosCard() {
    if (_stage == _SosStage.done && _result != null) {
      return _buildResultCard();
    }
    if (_stage == _SosStage.error) {
      return _buildErrorCard();
    }
    if (_stage == _SosStage.locating || _stage == _SosStage.sending) {
      return _buildProgressCard();
    }
    return _buildHoldButton();
  }

  Widget _buildHoldButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (_) {
              setState(() => _stage = _SosStage.holding);
              _holdController.forward(from: 0);
            },
            onLongPressEnd: (_) => _resetHold(),
            onLongPressCancel: () => _resetHold(),
            child: AnimatedBuilder(
              animation: _holdController,
              builder: (context, child) {
                return SizedBox(
                  width: 176,
                  height: 176,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 176,
                        height: 176,
                        child: CircularProgressIndicator(
                          value: _holdController.value,
                          strokeWidth: 5,
                          backgroundColor: AppColors.line,
                          valueColor: const AlwaysStoppedAnimation(AppColors.red),
                        ),
                      ),
                      Container(
                        width: 148,
                        height: 148,
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Mantén presionado 3 segundos',
            style: AppTheme.display(size: 15, w: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Enviará tu ubicación exacta por SMS a tus contactos de confianza'
              '${_communityOptIn ? " y a tu red comunitaria cercana" : ""}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.dim, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final label = _stage == _SosStage.locating
        ? 'Obteniendo tu ubicación exacta…'
        : 'Enviando SOS…';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.red),
          const SizedBox(height: 16),
          Text(label, style: AppTheme.display(size: 14, w: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle, color: AppColors.teal),
            const SizedBox(width: 8),
            Text('SOS procesado', style: AppTheme.display(size: 17)),
          ]),
          const SizedBox(height: 14),
          _resultLine(
            r.smsOpened,
            r.smsOpened
                ? 'Se abrió tu app de mensajes con tus coordenadas listas para enviar a ${_contacts.length} contacto(s).'
                : 'No se pudo abrir la app de mensajes.',
          ),
          const SizedBox(height: 8),
          if (_communityOptIn)
            _resultLine(
              r.communitySent,
              r.communitySent
                  ? 'Tu red comunitaria cercana fue notificada.'
                  : (r.communityError ?? 'No se pudo notificar a la red comunitaria.'),
            ),
          const SizedBox(height: 14),
          Text(
            'Coordenadas enviadas: ${r.position.latitude.toStringAsFixed(6)}, ${r.position.longitude.toStringAsFixed(6)}',
            style: AppTheme.mono(size: 11.5),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _resetAll,
              child: const Text('Ya estoy a salvo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultLine(bool ok, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ok ? Icons.check : Icons.error_outline, size: 16, color: ok ? AppColors.teal : AppColors.amber),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.dim, height: 1.4))),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.red.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.error_outline, color: AppColors.red),
            const SizedBox(width: 8),
            Text('No se pudo enviar', style: AppTheme.display(size: 16)),
          ]),
          const SizedBox(height: 10),
          Text(_errorText ?? 'Ocurrió un error.', style: const TextStyle(fontSize: 13, color: AppColors.dim, height: 1.5)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _resetAll, child: const Text('Reintentar')),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_outlined, color: AppColors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alertar a mi red comunitaria', style: AppTheme.display(size: 13.5, w: FontWeight.w600)),
                const SizedBox(height: 3),
                const Text(
                  'Opcional. Comparte tu ubicación con usuarios de ANTES en un radio de 2 km. Apagado por defecto.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.dim, height: 1.4),
                ),
              ],
            ),
          ),
          Switch(
            value: _communityOptIn,
            activeColor: AppColors.teal,
            onChanged: (v) async {
              await _sosService.setCommunityOptIn(v);
              setState(() => _communityOptIn = v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Contactos de confianza', style: AppTheme.display(size: 14.5)),
              TextButton.icon(
                onPressed: _showAddContactDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Añadir'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Estos números solo se guardan en tu teléfono. Añade al menos uno para poder usar el botón SOS.',
                style: TextStyle(fontSize: 12.5, color: AppColors.dim, height: 1.4),
              ),
            )
          else
            ..._contacts.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(backgroundColor: AppColors.bgElevated, child: Icon(Icons.person, color: AppColors.dim, size: 18)),
                  title: Text(c.name, style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(c.phone, style: AppTheme.mono(size: 11.5)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.dim),
                    onPressed: () async {
                      await _contactsRepo.remove(c.id);
                      _loadContacts();
                    },
                  ),
                )),
        ],
      ),
    );
  }

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Nuevo contacto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Teléfono (con indicativo, ej. +57...)'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
              await _contactsRepo.add(EmergencyContact(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
              _loadContacts();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

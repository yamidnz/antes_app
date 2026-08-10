import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Resultado de un intento de SOS, para mostrarle al usuario exactamente
/// qué se envió y a quién — nunca debe quedar en duda si el aviso salió o no.
class SosResult {
  final bool smsOpened;
  final bool communitySent;
  final String? communityError;
  final Position position;

  SosResult({
    required this.smsOpened,
    required this.communitySent,
    required this.position,
    this.communityError,
  });
}

/// -----------------------------------------------------------------------
/// DECISIONES DE SEGURIDAD Y PRIVACIDAD (léase antes de modificar este
/// archivo):
///
/// 1. El canal principal y por defecto es SMS a contactos de confianza
///    configurados por el propio usuario. Funciona incluso sin datos
///    móviles/WiFi (solo necesita señal celular), que es justo el
///    escenario típico tras un sismo fuerte cuando cae el internet.
///
/// 2. El canal "red comunitaria" es OPCIONAL y apagado por defecto
///    (opt-in). Difundir tu ubicación exacta a desconocidos cercanos
///    tiene beneficios (ayuda más rápida) pero también riesgos (abuso,
///    ubicación expuesta), así que el usuario decide activarlo
///    explícitamente en Ajustes, no la app por él.
///
/// 3. Nunca se publica en un canal público/abierto sin autenticar. El
///    envío a la red comunitaria debe ir siempre autenticado con un
///    token de usuario y acotado a un radio (ej. 2 km), para que el
///    backend pueda: (a) descartar spam/falsas alarmas, (b) no exponer
///    la identidad real del usuario a quien recibe la alerta, y (c)
///    dejar rastro de quién emitió cada SOS por si se abusa del sistema.
///    El endpoint de abajo es un STUB — se conecta a un backend real en
///    la Fase 2 (ver especificación técnica).
///
/// 4. Límite de frecuencia: no se permite disparar más de un SOS por
///    minuto, para evitar que un doble toque accidental sature a los
///    contactos o a la red comunitaria.
/// -----------------------------------------------------------------------
class SosService {
  static const _lastSentKey = 'antes_sos_last_sent_ms';
  static const _communityOptInKey = 'antes_sos_community_opt_in';

  // TODO(fase 2): reemplazar por el endpoint real del backend de ANTES.
  static const _communityEndpoint = 'https://api.antesapp.co/v1/sos';

  Future<bool> canSendNow() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastSentKey);
    if (last == null) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    return elapsed > 60000; // 1 minuto entre envíos
  }

  Future<void> _markSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSentKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isCommunityOptIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_communityOptInKey) ?? false;
  }

  Future<void> setCommunityOptIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_communityOptInKey, value);
  }

  String _mapsLink(Position pos) =>
      'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

  String _buildMessage(Position pos, {String? note}) {
    final time = DateTime.now();
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final base =
        'SOS — necesito ayuda. Mi ubicación exacta ($hh:$mm): ${_mapsLink(pos)}'
        ' (lat ${pos.latitude.toStringAsFixed(6)}, lon ${pos.longitude.toStringAsFixed(6)})';
    if (note != null && note.trim().isNotEmpty) {
      return '$base. Nota: ${note.trim()}';
    }
    return '$base. Enviado desde la app ANTES.';
  }

  /// Abre la app nativa de SMS con el mensaje y los destinatarios
  /// pre-cargados. El usuario final confirma el envío desde su propia
  /// app de mensajería — así ANTES nunca necesita permiso para enviar
  /// SMS en segundo plano, algo que además Google/Apple restringen mucho.
  Future<bool> sendSmsToContacts(
    List<EmergencyContact> contacts,
    Position pos, {
    String? note,
  }) async {
    if (contacts.isEmpty) return false;
    final body = Uri.encodeComponent(_buildMessage(pos, note: note));
    final numbers = contacts.map((c) => c.phone).join(',');
    final uri = Uri.parse('sms:$numbers?body=$body');
    return launchUrl(uri);
  }

  /// Notifica a la red comunitaria (usuarios de ANTES cercanos que se
  /// ofrecieron como respondientes). Requiere internet y opt-in previo.
  Future<(bool, String?)> notifyCommunity(
    Position pos, {
    String? note,
    double radiusKm = 2.0,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_communityEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': pos.latitude,
              'lon': pos.longitude,
              'accuracy_m': pos.accuracy,
              'timestamp': DateTime.now().toIso8601String(),
              'radius_km': radiusKm,
              'note': note,
              // 'auth_token': <token de sesión del usuario>, // Fase 2
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (true, null);
      }
      return (false, 'El servidor respondió ${res.statusCode}');
    } catch (e) {
      return (false, 'Sin conexión con la red comunitaria en este momento.');
    }
  }

  /// Orquesta el envío completo: ubicación ya obtenida + los canales que
  /// el usuario tenga habilitados.
  Future<SosResult> fireSos({
    required Position position,
    required List<EmergencyContact> contacts,
    String? note,
  }) async {
    final communityEnabled = await isCommunityOptIn();

    final smsOpened =
        await sendSmsToContacts(contacts, position, note: note);

    bool communitySent = false;
    String? communityError;
    if (communityEnabled) {
      final (ok, err) = await notifyCommunity(position, note: note);
      communitySent = ok;
      communityError = err;
    }

    await _markSent();

    return SosResult(
      smsOpened: smsOpened,
      communitySent: communitySent,
      communityError: communityError,
      position: position,
    );
  }
}

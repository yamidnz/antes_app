import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/emergency_contact.dart';

/// Los contactos de confianza viven SOLO en el dispositivo del usuario
/// (SharedPreferences), nunca en un servidor. Es la lista más sensible
/// de la app y no hay razón para que salga del teléfono.
class ContactsRepository {
  static const _key = 'antes_emergency_contacts';

  Future<List<EmergencyContact>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => EmergencyContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<EmergencyContact> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(contacts.map((c) => c.toJson()).toList());
    await prefs.setString(_key, raw);
  }

  Future<void> add(EmergencyContact contact) async {
    final all = await getAll();
    all.add(contact);
    await saveAll(all);
  }

  Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((c) => c.id == id);
    await saveAll(all);
  }
}

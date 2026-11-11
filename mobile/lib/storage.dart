// Ce que l'appli retient entre deux lancements : le « badge » d'appairage et la dernière adresse du PC.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'secure.dart';

class Storage {
  static const _pairingKey = 'pairing';
  static const _ipKey = 'last_ip';

  static Future<Pairing?> loadPairing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pairingKey);
      if (raw == null) return null;
      return Pairing.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePairing(Pairing p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pairingKey, jsonEncode(p.toJson()));
    } catch (_) {}
  }

  /// Oublie le PC appairé (et sa dernière adresse).
  static Future<void> forgetPairing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pairingKey);
      await prefs.remove(_ipKey);
    } catch (_) {}
  }

  static Future<String?> loadLastIp() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_ipKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLastIp(String ip) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_ipKey, ip);
    } catch (_) {}
  }
}

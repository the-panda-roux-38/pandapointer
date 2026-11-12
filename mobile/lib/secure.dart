// Sécurité côté téléphone : appairage et chiffrement des tickets.
//
// Image : un badge d'accès. Le PC fabrique le badge (une clé secrète) et le montre en QR code ;
// le téléphone le scanne et le garde. Ensuite, à chaque session, les deux se reconnaissent grâce
// à ce badge et chiffrent tout ce qu'ils s'envoient. Détails et formats : voir
// `pc-companion/src/secure.rs` (les deux fichiers doivent rester d'accord, des vecteurs de test
// communs le vérifient).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

const int kTypeAuthReq = 10;
const int kTypeAuthOk = 11;
const int kTypeAuthNo = 12;
const int kTypeSealed = 0xE1;
const int kTypePing = 13;
const int kTypePong = 14;

String bytesToHex(List<int> b) =>
    b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

Uint8List? hexToBytes(String s) {
  if (s.length.isOdd) return null;
  final out = Uint8List(s.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    final v = int.tryParse(s.substring(2 * i, 2 * i + 2), radix: 16);
    if (v == null) return null;
    out[i] = v;
  }
  return out;
}

Uint8List randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

Uint8List _hmac(Uint8List key, List<List<int>> parts) {
  final data = <int>[for (final p in parts) ...p];
  return Uint8List.fromList(Hmac(sha256, key).convert(data).bytes);
}

/// Clé propre à cette session : change à chaque connexion.
Uint8List sessionKey(Uint8List key, Uint8List cn, Uint8List sn) =>
    _hmac(key, [utf8.encode('pp-sess'), cn, sn]);

/// Signature par laquelle le PC prouve qu'il connaît la clé.
Uint8List serverTag(Uint8List key, Uint8List cn, Uint8List sn, Uint8List id) =>
    Uint8List.sublistView(
        _hmac(key, [utf8.encode('pp-srv'), cn, sn, id]), 0, 16);

Uint8List _nonce(int dir, int counter) {
  final d = ByteData(12);
  d.setUint8(0, dir);
  d.setUint64(4, counter, Endian.little);
  return d.buffer.asUint8List();
}

/// Chiffre un ticket. [dir] : 0 = téléphone→PC, 1 = PC→téléphone.
Uint8List sealPacket(Uint8List session, int dir, int counter, Uint8List inner) {
  final c = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
  c.init(
      true,
      AEADParameters(KeyParameter(session), 128, _nonce(dir, counter),
          Uint8List.fromList([kTypeSealed])));
  final out = Uint8List(c.getOutputSize(inner.length));
  var n = c.processBytes(inner, 0, inner.length, out, 0);
  n += c.doFinal(out, n);
  final head = ByteData(9);
  head.setUint8(0, kTypeSealed);
  head.setUint64(1, counter, Endian.little);
  return Uint8List.fromList(
      [...head.buffer.asUint8List(), ...out.sublist(0, n)]);
}

/// Déchiffre un ticket scellé ; null si la signature est mauvaise.
({int counter, Uint8List inner})? unsealPacket(
    Uint8List session, int dir, Uint8List data) {
  if (data.length < 9 + 16 || data[0] != kTypeSealed) return null;
  final counter = ByteData.sublistView(data).getUint64(1, Endian.little);
  try {
    final c = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
    c.init(
        false,
        AEADParameters(KeyParameter(session), 128, _nonce(dir, counter),
            Uint8List.fromList([kTypeSealed])));
    final body = Uint8List.sublistView(data, 9);
    final out = Uint8List(c.getOutputSize(body.length));
    var n = c.processBytes(body, 0, body.length, out, 0);
    n += c.doFinal(out, n);
    return (counter: counter, inner: Uint8List.fromList(out.sublist(0, n)));
  } catch (_) {
    return null; // signature invalide : ticket modifié ou clé différente
  }
}

Uint8List authRequest(Uint8List id, Uint8List cn) =>
    Uint8List.fromList([kTypeAuthReq, 0, 0, ...id, ...cn]);

/// Le « badge » : ce que le QR code contient et que le téléphone garde.
class Pairing {
  const Pairing(
      {required this.id,
      required this.key,
      required this.pcName,
      this.port = 4210,
      this.ip});

  final Uint8List id; // 8 octets
  final Uint8List key; // 32 octets
  final String pcName;
  final int port;

  /// Adresse du PC au moment de l'appairage (écrite dans le QR code) : évite la recherche
  /// par diffusion, que certaines box ou le Wi-Fi bloquent. Non conservée dans le badge.
  final String? ip;

  /// Lit le lien du QR code : pandapointer://pair?v=1&id=...&k=...&n=...&p=4210
  static Pairing? fromUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null || uri.scheme != 'pandapointer' || uri.host != 'pair') {
      return null;
    }
    final id = hexToBytes(uri.queryParameters['id'] ?? '');
    final key = hexToBytes(uri.queryParameters['k'] ?? '');
    if (id == null || id.length != 8 || key == null || key.length != 32) {
      return null;
    }
    return Pairing(
      id: id,
      key: key,
      pcName: uri.queryParameters['n'] ?? 'PC',
      port: int.tryParse(uri.queryParameters['p'] ?? '') ?? 4210,
      ip: _cleanIp(uri.queryParameters['a']),
    );
  }

  static String? _cleanIp(String? v) {
    if (v == null) return null;
    final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$').firstMatch(v);
    if (m == null) return null;
    for (var i = 1; i <= 4; i++) {
      if (int.parse(m.group(i)!) > 255) return null;
    }
    return v;
  }

  Map<String, Object> toJson() => {
        'id': bytesToHex(id),
        'k': bytesToHex(key),
        'n': pcName,
        'p': port,
      };

  static Pairing? fromJson(Map<String, dynamic> j) {
    final id = hexToBytes('${j['id']}');
    final key = hexToBytes('${j['k']}');
    if (id == null || key == null || id.length != 8 || key.length != 32) {
      return null;
    }
    return Pairing(
        id: id,
        key: key,
        pcName: '${j['n'] ?? 'PC'}',
        port: (j['p'] as int?) ?? 4210);
  }
}

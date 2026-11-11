// Vérifie que le téléphone calcule exactement les mêmes octets que le PC
// (vecteurs produits par pc-companion/src/secure.rs et recoupés avec une autre implémentation).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/secure.dart';

void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final id = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
  final cn = Uint8List.fromList(List.generate(8, (i) => 0x10 + i));
  final sn = Uint8List.fromList(List.generate(16, (i) => 0x20 + i));

  test('clé de session et signature du PC identiques au PC', () {
    expect(bytesToHex(sessionKey(key, cn, sn)),
        '09c8e6305a164772a14078ed6d78e7e29290b4dbc9798a9313b3c7ac2f8ed1e6');
    expect(bytesToHex(serverTag(key, cn, sn, id)),
        'd9f908ee688cca7d11a858714390535a');
  });

  test('ticket chiffré identique à celui du PC', () {
    final sk = sessionKey(key, cn, sn);
    final sealed = sealPacket(sk, 0, 1, Uint8List.fromList([4, 0, 0, 1]));
    expect(bytesToHex(sealed),
        'e10100000000000000a3a4e278e4770513e97bd377297f3c2f8be80f07');
  });

  test('aller-retour, mauvais sens et ticket modifié refusés', () {
    final sk = sessionKey(key, cn, sn);
    final inner = Uint8List.fromList([1, 0, 0, 5, 0, 250, 255]);
    final s = sealPacket(sk, 0, 7, inner);
    final back = unsealPacket(sk, 0, s)!;
    expect(back.counter, 7);
    expect(back.inner, inner);
    expect(unsealPacket(sk, 1, s), isNull);
    final bad = Uint8List.fromList(s)..[s.length - 1] ^= 1;
    expect(unsealPacket(sk, 0, bad), isNull);
    expect(unsealPacket(Uint8List(32), 0, s), isNull);
  });

  test('demande d\'authentification', () {
    expect(bytesToHex(authRequest(id, cn)),
        '0a0000${bytesToHex(id)}${bytesToHex(cn)}');
  });

  test('lien du QR code', () {
    final url =
        'pandapointer://pair?v=1&id=${bytesToHex(id)}&k=${bytesToHex(key)}&n=PC%20PANDA%20%C3%A9&p=4210';
    final p = Pairing.fromUrl(url)!;
    expect(p.id, id);
    expect(p.key, key);
    expect(p.pcName, 'PC PANDA é');
    expect(p.port, 4210);
    final again = Pairing.fromJson(p.toJson())!;
    expect(again.key, key);
    expect(Pairing.fromUrl('https://exemple.fr'), isNull);
    expect(Pairing.fromUrl('pandapointer://pair?id=zz&k=00'), isNull);
  });
}

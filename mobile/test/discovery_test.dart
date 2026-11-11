// Vérifie la recherche automatique : format des tickets (alignés avec le PC),
// liste des adresses à appeler, et lecture des réponses.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/discovery.dart';
import 'package:pandapointer/link.dart';

void main() {
  test('ticket HELLO', () {
    expect(Packets.hello(0), [8, 0, 0]);
  });

  test('réponse du PC lue correctement (mêmes octets que protocol.rs)', () {
    final reply =
        Uint8List.fromList([9, 0, 0, 8, 80, 67, 95, 80, 65, 78, 68, 65]);
    expect(parseHere(reply), 'PC_PANDA');
  });

  test('réponses invalides refusées', () {
    expect(parseHere(Uint8List.fromList([])), isNull);
    expect(parseHere(Uint8List.fromList([9, 0, 0])), isNull);
    expect(parseHere(Uint8List.fromList([9, 0, 0, 5, 65])),
        isNull); // longueur fausse
    expect(parseHere(Uint8List.fromList([4, 0, 0, 1, 65])),
        isNull); // autre type de ticket
    expect(parseHere(Uint8List.fromList([9, 0, 0, 1, 0xFF])),
        isNull); // pas de l'UTF-8
  });

  test('seuls les réseaux locaux sont balayés', () {
    expect(isPrivateIPv4('192.168.43.1'), true);
    expect(isPrivateIPv4('10.20.30.40'), true);
    expect(isPrivateIPv4('172.16.0.5'), true);
    expect(isPrivateIPv4('172.32.0.5'), false);
    expect(isPrivateIPv4('8.8.8.8'), false);
    expect(isPrivateIPv4('100.64.1.1'),
        false); // réseau mobile partagé de l'opérateur
    expect(isPrivateIPv4('abc'), false);
  });

  test('balayage du réseau du partage de connexion', () {
    final list = sweepFor('192.168.43.1');
    expect(list.first, '192.168.43.255'); // la diffusion d'abord
    expect(list.contains('192.168.43.2'), true);
    expect(list.contains('192.168.43.254'), true);
    expect(list.contains('192.168.43.1'), false); // pas soi-même
    expect(list.length, 254); // 253 voisins + la diffusion
  });
}

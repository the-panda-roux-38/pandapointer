// Test d'intégration de la liaison : un faux PC (réseau local de la machine) parle avec le vrai Link.
// On vérifie l'authentification, le chiffrement, le ping/pong, la coupure et la reconnexion automatique.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/link.dart';
import 'package:pandapointer/secure.dart';

/// Un PC minimal : mêmes règles que pc-companion/src/secure.rs.
class FakePc {
  FakePc(this.socket, this.pairing) {
    socket.listen((e) {
      if (e != RawSocketEvent.read) return;
      Datagram? d;
      while ((d = socket.receive()) != null) {
        _onDatagram(d!);
      }
    });
  }

  final RawDatagramSocket socket;
  final Pairing pairing;
  bool mute = false; // simule une coupure réseau : plus aucune réponse
  bool refuse = false; // simule « je ne te connais pas »
  Uint8List? _session;
  int _lastCounter = 0;
  int _outCounter = 0;
  final received = <Uint8List>[];
  int authCount = 0;

  static Future<FakePc> start(Pairing p) async =>
      FakePc(await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0), p);

  int get port => socket.port;

  void _onDatagram(Datagram d) {
    if (mute) return;
    final data = d.data;
    if (data[0] == kTypeAuthReq && data.length == 19) {
      authCount++;
      if (refuse) {
        socket.send([kTypeAuthNo, 0, 0], d.address, d.port);
        return;
      }
      final cn = Uint8List.sublistView(data, 11, 19);
      final sn = randomBytes(16);
      _session = sessionKey(pairing.key, Uint8List.fromList(cn), sn);
      _lastCounter = 0;
      socket.send([
        kTypeAuthOk,
        0,
        0,
        ...sn,
        ...serverTag(pairing.key, Uint8List.fromList(cn), sn, pairing.id),
      ], d.address, d.port);
    } else if (data[0] == kTypeSealed && _session != null) {
      final o = unsealPacket(_session!, 0, data);
      if (o == null || o.counter <= _lastCounter) return;
      _lastCounter = o.counter;
      if (o.inner[0] == kTypePing) {
        _outCounter++;
        socket.send(
            sealPacket(_session!, 1, _outCounter,
                Uint8List.fromList([kTypePong, 0, 0])),
            d.address,
            d.port);
      } else {
        received.add(o.inner);
      }
    }
  }
}

Future<void> waitFor(bool Function() cond,
    {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) fail('délai dépassé');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  final pairing = Pairing(
      id: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
      key: Uint8List.fromList(List.generate(32, (i) => 100 + i)),
      pcName: 'PC_TEST');

  test('connexion, ticket chiffré, coupure puis reconnexion automatique',
      () async {
    final pc = await FakePc.start(pairing);
    final link = Link(
        port: pc.port,
        tickEvery: const Duration(milliseconds: 100),
        silenceLimit: const Duration(milliseconds: 500));
    link.setPairing(pairing);
    await link.connect('127.0.0.1');
    await waitFor(() => link.online);
    expect(link.status, contains('PC_TEST'));

    link.sendMove(5, -6);
    await waitFor(() => pc.received.isNotEmpty);
    expect(pc.received.first, [1, 1, 0, 5, 0, 250, 255]);

    // Coupure : le PC ne répond plus, le lien le remarque.
    pc.mute = true;
    await waitFor(() => !link.online);
    expect(link.connected, true); // il veut toujours être relié
    link.sendMove(1, 1); // jeté sans erreur
    final before = pc.authCount;

    // Retour : reconnexion toute seule, avec une nouvelle session.
    pc.mute = false;
    await waitFor(() => link.online);
    expect(pc.authCount, greaterThan(before));
    link.sendSlide(SlideAction.next);
    await waitFor(() => pc.received.length >= 2);
    expect(
        pc.received.last, [4, 1, 0, 1]); // numéro repart de 1 avec la session

    link.dispose();
    pc.socket.close();
  });

  test('PC qui ne connait pas le téléphone : message clair, pas de boucle',
      () async {
    final pc = await FakePc.start(pairing);
    pc.refuse = true;
    final link = Link(
        port: pc.port,
        tickEvery: const Duration(milliseconds: 100),
        silenceLimit: const Duration(milliseconds: 500));
    link.setPairing(pairing);
    await link.connect('127.0.0.1');
    await waitFor(() => link.status.contains('QR code'));
    expect(link.online, false);
    final n = pc.authCount;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(pc.authCount, n); // il n'insiste pas
    link.dispose();
    pc.socket.close();
  });

  test('le PC change d\'adresse : le lien le retrouve par son nom', () async {
    final pc = await FakePc.start(pairing);
    final link = Link(
        port: pc.port,
        tickEvery: const Duration(milliseconds: 100),
        silenceLimit: const Duration(milliseconds: 500));
    link.setPairing(pairing);
    String? asked;
    link.findPc = (name) async {
      asked = name;
      return '127.0.0.1';
    };
    // Adresse de départ fausse (autre IP de la machine, sans PC dessus).
    await link.connect('127.0.0.2');
    await waitFor(() => link.online, timeout: const Duration(seconds: 6));
    expect(asked, 'PC_TEST');
    link.dispose();
    pc.socket.close();
  });

  test('sans appairage : refuse de se connecter', () async {
    final link = Link();
    await link.connect('127.0.0.1');
    expect(link.connected, false);
    expect(link.status, contains('appair'));
    link.dispose();
  });
}

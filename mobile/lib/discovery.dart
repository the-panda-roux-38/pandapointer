// Recherche automatique du PC sur le réseau.
//
// Pourquoi : sur le partage de connexion du téléphone (ou un Wi-Fi qu'on ne connaît pas),
// le PC reçoit une adresse IP différente à chaque fois. Plutôt que de la taper à la main,
// le téléphone "appelle" et le PC répond. Image : crier « il y a quelqu'un ? » dans un couloir.
//
// Deux façons d'appeler en même temps, car certains réseaux filtrent l'une ou l'autre :
//   1. la diffusion (broadcast) : un seul cri entendu par tout le monde sur le réseau ;
//   2. le balayage : on frappe à chaque porte de la rue (192.168.43.1 à .254).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'link.dart';

class FoundPc {
  const FoundPc(this.name, this.address);
  final String name;
  final InternetAddress address;
}

/// Lit la réponse d'un PC : [9, 0, 0, longueur, nom...]. null si ce n'est pas une réponse valide.
String? parseHere(Uint8List data) {
  if (data.length < 4 || data[0] != kTypeHere) return null;
  final n = data[3];
  if (data.length != 4 + n) return null;
  try {
    return utf8.decode(data.sublist(4));
  } on FormatException {
    return null;
  }
}

/// Adresse de réseau local (192.168.x.x, 10.x.x.x, 172.16-31.x.x) ?
/// On ne balaie que ceux-là : inutile de frapper aux portes d'Internet.
bool isPrivateIPv4(String ip) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((e) => e == null)) return false;
  final a = p[0]!, b = p[1]!;
  return a == 10 || (a == 192 && b == 168) || (a == 172 && b >= 16 && b <= 31);
}

/// Toutes les adresses à appeler pour un téléphone qui a l'adresse [ownIp] :
/// la diffusion du réseau (x.y.z.255) puis chaque voisin possible (x.y.z.1 à .254), sauf lui-même.
/// (On suppose un réseau de type /24, ce qui est le cas de la quasi-totalité des box et partages de connexion.)
List<String> sweepFor(String ownIp) {
  final parts = ownIp.split('.');
  final prefix = parts.take(3).join('.');
  final out = <String>['$prefix.255'];
  for (var i = 1; i <= 254; i++) {
    final ip = '$prefix.$i';
    if (ip != ownIp) out.add(ip);
  }
  return out;
}

/// Toutes les adresses à appeler, d'après les réseaux auxquels le téléphone est branché
/// (Wi-Fi, partage de connexion...).
Future<List<InternetAddress>> localTargets() async {
  final out = <String>{'255.255.255.255'};
  try {
    final interfaces =
        await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final nic in interfaces) {
      for (final addr in nic.addresses) {
        if (isPrivateIPv4(addr.address)) out.addAll(sweepFor(addr.address));
      }
    }
  } catch (_) {
    // Liste des réseaux indisponible : il restera la diffusion générale.
  }
  return out.map(InternetAddress.new).toList();
}

/// Cherche les PC PandaPointer. Renvoie ceux qui ont répondu (peut être vide).
/// [targets] et [port] ne servent qu'aux tests.
Future<List<FoundPc>> discoverPcs({
  List<InternetAddress>? targets,
  int port = kPort,
  Duration timeout = const Duration(milliseconds: 2200),
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;
  final found = <String, FoundPc>{};
  final sub = socket.listen((event) {
    if (event != RawSocketEvent.read) return;
    Datagram? d;
    while ((d = socket.receive()) != null) {
      final name = parseHere(d!.data);
      if (name != null) found[d.address.address] = FoundPc(name, d.address);
    }
  });

  try {
    final list = targets ?? await localTargets();
    final hello = Packets.hello(0);
    final started = DateTime.now();
    // Deux passages : l'UDP peut perdre un paquet, et la file d'envoi se remplit vite,
    // donc on envoie par petits paquets de 32 avec une courte pause.
    for (var pass = 0; pass < 2; pass++) {
      for (var i = 0; i < list.length; i++) {
        try {
          socket.send(hello, list[i], port);
        } catch (_) {
          // Cette adresse n'est pas joignable (ex. diffusion refusée) : on passe à la suivante.
        }
        if (i % 32 == 31) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    final left = timeout - DateTime.now().difference(started);
    if (!left.isNegative) {
      await Future<void>.delayed(left);
    }
  } finally {
    await sub.cancel();
    socket.close();
  }
  return found.values.toList();
}

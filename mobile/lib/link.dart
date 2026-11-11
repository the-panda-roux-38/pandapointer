// La "liaison" avec le PC : tout ce qui concerne le réseau est ici.
// Les pages (gyro, pavé, diaporama) ne connaissent que des méthodes simples
// comme `sendMove` ou `sendSlide`, jamais les octets.
//
// Le format des octets est décrit côté PC dans `pc-companion/src/protocol.rs` :
// les deux fichiers doivent toujours rester d'accord.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'secure.dart';

const int kPort = 4210; // doit être le même que côté PC

const int kTypeMove = 1;
const int kTypeButton = 2;
const int kTypeScroll = 3;
const int kTypeSlide = 4;
const int kTypeGesture = 5;
const int kTypeZoom = 6;
const int kTypeLaser = 7;
const int kTypeHello = 8;
const int kTypeHere = 9;

enum MouseButton { left, right }

enum SlideAction { next, previous, start, stop }

/// Gestes système (3 et 4 doigts). L'ordre compte : numéro d'octet = index + 1.
enum GestureAction {
  taskView,
  showDesktop,
  nextApp,
  previousApp,
  search,
  notifications,
  desktopLeft,
  desktopRight,
}

/// Fabrique les "tickets" (paquets). Fonctions pures : faciles à tester.
class Packets {
  static Uint8List move(int seq, int dx, int dy) {
    final d = ByteData(7);
    d.setUint8(0, kTypeMove);
    d.setUint16(1, seq, Endian.little);
    d.setInt16(3, dx.clamp(-32768, 32767).toInt(), Endian.little);
    d.setInt16(5, dy.clamp(-32768, 32767).toInt(), Endian.little);
    return d.buffer.asUint8List();
  }

  /// state : 0 = relâcher, 1 = enfoncer, 2 = clic complet.
  static Uint8List button(int seq, MouseButton button, int state) {
    final d = ByteData(5);
    d.setUint8(0, kTypeButton);
    d.setUint16(1, seq, Endian.little);
    d.setUint8(3, button == MouseButton.left ? 1 : 2);
    d.setUint8(4, state);
    return d.buffer.asUint8List();
  }

  /// Crans de molette. dx : positif = vers la droite. dy : positif = vers le bas.
  static Uint8List scroll(int seq, int dx, int dy) {
    final d = ByteData(7);
    d.setUint8(0, kTypeScroll);
    d.setUint16(1, seq, Endian.little);
    d.setInt16(3, dx.clamp(-32768, 32767).toInt(), Endian.little);
    d.setInt16(5, dy.clamp(-32768, 32767).toInt(), Endian.little);
    return d.buffer.asUint8List();
  }

  static Uint8List slide(int seq, SlideAction action) {
    final d = ByteData(4);
    d.setUint8(0, kTypeSlide);
    d.setUint16(1, seq, Endian.little);
    d.setUint8(
        3, action.index + 1); // 1 suivant, 2 précédent, 3 démarrer, 4 quitter
    return d.buffer.asUint8List();
  }

  static Uint8List gesture(int seq, GestureAction action) {
    final d = ByteData(4);
    d.setUint8(0, kTypeGesture);
    d.setUint16(1, seq, Endian.little);
    d.setUint8(3, action.index + 1);
    return d.buffer.asUint8List();
  }

  /// « Y a-t-il un PC PandaPointer ici ? » (recherche automatique).
  static Uint8List hello(int seq) {
    final d = ByteData(3);
    d.setUint8(0, kTypeHello);
    d.setUint16(1, seq, Endian.little);
    return d.buffer.asUint8List();
  }

  /// Allume (true) ou éteint (false) le laser sur le PC.
  static Uint8List laser(int seq, bool on) {
    final d = ByteData(4);
    d.setUint8(0, kTypeLaser);
    d.setUint16(1, seq, Endian.little);
    d.setUint8(3, on ? 1 : 0);
    return d.buffer.asUint8List();
  }

  /// steps : crans de zoom, positif = zoom avant.
  static Uint8List zoom(int seq, int steps) {
    final d = ByteData(5);
    d.setUint8(0, kTypeZoom);
    d.setUint16(1, seq, Endian.little);
    d.setInt16(3, steps.clamp(-32768, 32767).toInt(), Endian.little);
    return d.buffer.asUint8List();
  }
}

/// La liaison avec le PC. Elle s'occupe de tout : authentification, chiffrement, battement
/// de coeur (ping) et reconnexion automatique si le Wi-Fi coupe ou si le PC change d'adresse.
///
/// Deux idées à ne pas confondre :
///   - `connected` : « je veux être relié au PC » (le bouton Connecter a été pressé) ;
///   - `online`    : « la liaison fonctionne vraiment là, maintenant » (le PC répond).
class Link extends ChangeNotifier {
  Link({
    this.port = kPort,
    this.tickEvery = const Duration(seconds: 1),
    this.silenceLimit = const Duration(seconds: 4),
  });

  final int port;
  final Duration tickEvery;
  final Duration silenceLimit;

  /// Appelé quand le PC ne répond plus à son adresse : cherche-le sur le réseau par son nom
  /// et renvoie sa nouvelle adresse (ou null). Branché par l'écran principal.
  Future<String?> Function(String pcName)? findPc;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _sub;
  InternetAddress? _target;
  Timer? _tick;

  Pairing? pairing;
  Uint8List? _session;
  int _sendCounter = 0;
  Uint8List? _clientNonce;
  DateTime _lastHandshake = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHeard = DateTime.now();
  int _failedHandshakes = 0;
  bool _rejected = false;
  bool _searching = false;

  int _seq = 0;
  int sent = 0;
  bool online = false;
  String status = 'Pas connecté';

  /// Adresse IP du PC à laquelle on est relié (null si pas connecté).
  String? get address => _target?.address;

  /// « Je veux être relié au PC » (la liaison peut être en cours de rétablissement).
  bool get connected => _socket != null;

  void setPairing(Pairing? p) {
    pairing = p;
    notifyListeners();
  }

  Future<void> connect(String ip) async {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) {
      status = 'Adresse IP invalide (exemple : 192.168.1.20)';
      notifyListeners();
      return;
    }
    final pair = pairing;
    if (pair == null) {
      status = "Pas encore appairé : scanne le QR code du PC d'abord";
      notifyListeners();
      return;
    }
    _close();
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket = socket;
      _sub = socket.listen((e) {
        if (e != RawSocketEvent.read) return;
        Datagram? d;
        while ((d = socket.receive()) != null) {
          _onDatagram(d!);
        }
      });
      _target = address;
      sent = 0;
      _rejected = false;
      _failedHandshakes = 0;
      status = 'Connexion à ${address.address}...';
      _tick = Timer.periodic(tickEvery, (_) => _onTick());
      _handshake();
    } catch (e) {
      _close();
      status = 'Connexion impossible : $e';
    }
    notifyListeners();
  }

  void _handshake() {
    final pair = pairing;
    final socket = _socket;
    final target = _target;
    if (pair == null || socket == null || target == null) return;
    _clientNonce = randomBytes(8);
    _lastHandshake = DateTime.now();
    socket.send(authRequest(pair.id, _clientNonce!), target, port);
  }

  void _onDatagram(Datagram d) {
    if (_target != null && d.address != _target) return;
    final data = d.data;
    final pair = pairing;
    if (data.isEmpty || pair == null) return;
    if (data[0] == kTypeAuthOk && data.length == 35 && _clientNonce != null) {
      final sn = Uint8List.sublistView(data, 3, 19);
      final tag = Uint8List.sublistView(data, 19, 35);
      final expected = serverTag(pair.key, _clientNonce!, sn, pair.id);
      var same = true;
      for (var i = 0; i < 16; i++) {
        if (tag[i] != expected[i]) same = false;
      }
      if (!same) {
        return; // ce n'est pas notre PC (il ne connaît pas la clé) : on ignore
      }
      _session = sessionKey(pair.key, _clientNonce!, Uint8List.fromList(sn));
      _clientNonce = null;
      _sendCounter = 0;
      _seq = 0;
      _lastHeard = DateTime.now();
      _failedHandshakes = 0;
      online = true;
      status = 'Connecté à ${pair.pcName} (${_target!.address})';
      notifyListeners();
    } else if (data[0] == kTypeAuthNo) {
      _rejected = true;
      online = false;
      _session = null;
      status =
          'Ce PC ne reconnaît pas ce téléphone : scanne un nouveau QR code';
      notifyListeners();
    } else if (data[0] == kTypeSealed && _session != null) {
      final opened = unsealPacket(_session!, 1, data);
      if (opened != null) {
        _lastHeard = DateTime.now(); // pong ou autre : le PC est là
      }
    }
  }

  void _onTick() {
    if (_socket == null || _rejected) return;
    if (online) {
      if (DateTime.now().difference(_lastHeard) > silenceLimit) {
        online = false;
        _session = null;
        _failedHandshakes = 0;
        status = 'Liaison perdue, reconnexion...';
        notifyListeners();
        _handshake();
      } else {
        _send(_ping());
      }
      return;
    }
    // Pas en ligne : on retente l'authentification, et si le PC reste muet on le recherche
    // sur le réseau (son adresse a pu changer, par exemple après un partage de connexion).
    if (DateTime.now().difference(_lastHandshake) >= tickEvery) {
      _failedHandshakes++;
      if (_failedHandshakes >= 3 && !_searching) _research();
      _handshake();
    }
  }

  Future<void> _research() async {
    final pair = pairing;
    final finder = findPc;
    if (pair == null || finder == null) return;
    _searching = true;
    try {
      final ip = await finder(pair.pcName);
      final address = ip == null ? null : InternetAddress.tryParse(ip);
      if (address != null && address != _target && _socket != null) {
        _target = address;
        status = 'PC retrouvé à ${address.address}...';
        notifyListeners();
        _handshake();
      }
    } finally {
      _searching = false;
    }
  }

  Uint8List _ping() => Uint8List.fromList([kTypePing, 0, 0]);

  void reportProblem(String message) {
    status = message;
    notifyListeners();
  }

  void _close() {
    _tick?.cancel();
    _tick = null;
    _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
    _target = null;
    _session = null;
    online = false;
  }

  void disconnect() {
    _close();
    status = 'Pas connecté';
    notifyListeners();
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  int _nextSeq() {
    _seq = (_seq + 1) & 0xFFFF;
    return _seq;
  }

  /// Envoie un ticket, chiffré. Hors ligne, il est simplement jeté (un mouvement de souris
  /// vieux de quelques secondes ne sert plus à rien).
  void _send(Uint8List inner) {
    final socket = _socket;
    final target = _target;
    final session = _session;
    if (socket == null || target == null || session == null || !online) return;
    _sendCounter++;
    socket.send(sealPacket(session, 0, _sendCounter, inner), target, port);
    sent++;
    if (sent % 25 == 0) notifyListeners(); // rafraîchit le compteur à l'écran
  }

  void sendMove(int dx, int dy) => _send(Packets.move(_nextSeq(), dx, dy));
  void sendButton(MouseButton b, bool pressed) =>
      _send(Packets.button(_nextSeq(), b, pressed ? 1 : 0));
  void sendClick(MouseButton b) => _send(Packets.button(_nextSeq(), b, 2));
  void sendScroll(int dx, int dy) => _send(Packets.scroll(_nextSeq(), dx, dy));
  void sendGesture(GestureAction a) => _send(Packets.gesture(_nextSeq(), a));
  void sendLaser(bool on) => _send(Packets.laser(_nextSeq(), on));
  void sendZoom(int steps) => _send(Packets.zoom(_nextSeq(), steps));
  void sendSlide(SlideAction a) => _send(Packets.slide(_nextSeq(), a));
}

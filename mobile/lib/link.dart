// La "liaison" avec le PC : tout ce qui concerne le réseau est ici.
// Les pages (gyro, pavé, diaporama) ne connaissent que des méthodes simples
// comme `sendMove` ou `sendSlide`, jamais les octets.
//
// Le format des octets est décrit côté PC dans `pc-companion/src/protocol.rs` :
// les deux fichiers doivent toujours rester d'accord.

import 'dart:io';

import 'package:flutter/foundation.dart';

const int kPort = 4210; // doit être le même que côté PC

const int kTypeMove = 1;
const int kTypeButton = 2;
const int kTypeScroll = 3;
const int kTypeSlide = 4;
const int kTypeGesture = 5;
const int kTypeZoom = 6;
const int kTypeLaser = 7;

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

class Link extends ChangeNotifier {
  RawDatagramSocket? _socket;
  InternetAddress? _target;
  int _seq = 0;
  int sent = 0;
  String status = 'Pas connecté';

  bool get connected => _socket != null;

  Future<void> connect(String ip) async {
    final address = InternetAddress.tryParse(ip.trim());
    if (address == null) {
      status = 'Adresse IP invalide (exemple : 192.168.1.20)';
      notifyListeners();
      return;
    }
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _target = address;
      _seq = 0;
      sent = 0;
      status = 'Connecté à ${address.address}';
    } catch (e) {
      status = 'Connexion impossible : $e';
    }
    notifyListeners();
  }

  /// Affiche un message dans la barre d'état (ex. : le gyroscope a refusé de démarrer).
  void reportProblem(String message) {
    status = message;
    notifyListeners();
  }

  void _close() {
    _socket?.close();
    _socket = null;
    _target = null;
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

  void _send(Uint8List bytes) {
    final socket = _socket;
    final target = _target;
    if (socket == null || target == null) return;
    socket.send(bytes, target, kPort);
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

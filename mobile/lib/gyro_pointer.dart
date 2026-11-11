// Le gyroscope en "pointeur", partagé entre l'onglet Gyro et l'onglet Slides.
// Les réglages (sensibilité, inversions) sont communs aux deux onglets :
// tu règles une fois, ça vaut partout.
//
// Le gyroscope n'est écouté que pendant qu'il sert (économise la batterie).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'link.dart';

class GyroPointer extends ChangeNotifier {
  GyroPointer(this.link) {
    link.addListener(_refresh); // si on se déconnecte, on arrête de pointer
  }

  final Link link;

  // Réglages
  double sensitivity = 800; // pixels par radian tourné
  bool invertX = false;
  bool invertY = false;

  /// Onglet Slides : false = "maintenir un bouton", true = "toujours actif".
  bool continuousMode = false;

  /// Onglet Slides : false = le pointeur est le vrai curseur, true = un point laser rouge.
  bool laserStyle = false;

  bool _holding = false; // un bouton "maintiens pour bouger" est enfoncé
  bool _continuousOn = false; // l'interrupteur "pointeur actif" est allumé
  bool _slidesMode = false; // l'onglet Slides est affiché

  StreamSubscription<GyroscopeEvent>? _sub;
  bool _wasMoving = false;
  bool _laserWasOn = false;
  Timer?
      _laserBeat; // petit signal régulier pour que le PC garde le laser allumé
  DateTime? _lastEvent;
  double _remX = 0, _remY = 0; // reste fractionnaire en pixels

  /// Le laser est-il utilisé en ce moment ? (seulement sur l'onglet Slides, en pointant)
  bool get laserActive => moving && _slidesMode && laserStyle;

  bool get holding => _holding;
  bool get continuousOn => _continuousOn;

  /// Le curseur suit-il le téléphone en ce moment ?
  bool get moving =>
      link.connected &&
      (_holding || (_slidesMode && continuousMode && _continuousOn));

  set holding(bool v) {
    _holding = v;
    _refresh();
  }

  set continuousOn(bool v) {
    _continuousOn = v;
    _refresh();
  }

  set slidesMode(bool v) {
    _slidesMode = v;
    _refresh();
  }

  void setContinuousMode(bool v) {
    continuousMode = v;
    if (!v) _continuousOn = false; // jamais de mode continu "par surprise"
    _refresh();
  }

  void setLaserStyle(bool v) {
    laserStyle = v;
    _refresh();
  }

  void update(void Function() change) {
    change();
    notifyListeners();
  }

  void _refresh() {
    final m = moving;
    if (m != _wasMoving) {
      _wasMoving = m;
      if (m) {
        _remX = 0;
        _remY = 0;
        _lastEvent = DateTime.now();
        _sub = gyroscopeEventStream(samplingPeriod: SensorInterval.gameInterval)
            .listen(_onGyro);
      } else {
        _sub?.cancel();
        _sub = null;
      }
    }
    _refreshLaser();
    notifyListeners();
  }

  /// Allume / éteint le laser du PC quand on commence / arrête de pointer.
  void _refreshLaser() {
    final on = laserActive;
    if (on == _laserWasOn) return;
    _laserWasOn = on;
    _laserBeat?.cancel();
    _laserBeat = null;
    link.sendLaser(on);
    if (on) {
      // Le PC éteint le laser après 3 s de silence : si on tient le téléphone
      // immobile, on lui rappelle toutes les secondes qu'on est toujours là.
      _laserBeat = Timer.periodic(
          const Duration(seconds: 1), (_) => link.sendLaser(true));
    }
  }

  void _onGyro(GyroscopeEvent e) {
    final now = DateTime.now();
    final last = _lastEvent;
    _lastEvent = now;
    if (last == null) return;
    final dt = now.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.2) return; // mesure aberrante : on ignore

    // Téléphone à plat, bord supérieur vers l'écran : rotation autour de z =
    // horizontal, autour de x = vertical. vitesse x durée = angle ; angle x
    // sensibilité = pixels.
    double dx = -e.z * dt * sensitivity;
    double dy = -e.x * dt * sensitivity;
    if (invertX) dx = -dx;
    if (invertY) dy = -dy;

    // Le reste fractionnaire est gardé pour l'envoi suivant (sinon les petits
    // mouvements lents seraient perdus).
    dx += _remX;
    dy += _remY;
    final ix = dx.round();
    final iy = dy.round();
    _remX = dx - ix;
    _remY = dy - iy;

    if (ix != 0 || iy != 0) link.sendMove(ix, iy);
  }

  @override
  void dispose() {
    link.removeListener(_refresh);
    _laserBeat?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

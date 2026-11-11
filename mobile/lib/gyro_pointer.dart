// Le gyroscope en "pointeur", partagé entre l'onglet Gyro et l'onglet Slides.
// Les réglages (sensibilité, inversions) sont communs aux deux onglets :
// tu règles une fois, ça vaut partout.
//
// Le gyroscope n'est écouté que pendant qu'il sert (économise la batterie).
// Le calcul des pixels (anti-tremblement, précision...) est dans gyro_filter.dart.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'gyro_filter.dart';
import 'link.dart';

class GyroPointer extends ChangeNotifier {
  GyroPointer(this.link) {
    link.addListener(_refresh); // si on se déconnecte, on arrête de pointer
  }

  final Link link;

  /// Transforme la rotation brute en pixels propres (réglages : sensibilité, stabilité, précision).
  final GyroFilter filter = GyroFilter();

  // Réglages (les trois premiers vivent dans le filtre)
  double get sensitivity => filter.sensitivity; // pixels par radian tourné
  set sensitivity(double v) => filter.sensitivity = v;
  double get stability => filter.stability; // 0 = réactif, 1 = très stable
  set stability(double v) => filter.stability = v;
  double get precision =>
      filter.precision; // 0 = linéaire, 1 = petits mouvements démultipliés
  set precision(double v) => filter.precision = v;
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
  DateTime?
      _lastStamp; // heure de la mesure précédente, donnée par le capteur lui-même
  double _accX = 0, _accY = 0; // pixels calculés, pas encore envoyés
  final Stopwatch _clock =
      Stopwatch(); // pour envoyer les mouvements par petits groupes
  int _lastSendMs = 0;

  /// Le capteur est lu toutes les 5 ms (200 fois par seconde, le maximum autorisé sans
  /// permission spéciale), mais on n'envoie au PC qu'environ toutes les 7 ms :
  /// moins de paquets, et le curseur reste fluide.
  static const Duration _samplingPeriod = Duration(milliseconds: 5);
  static const int _sendEveryMs = 7;

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
        _accX = 0;
        _accY = 0;
        _lastStamp = null;
        filter.restart();
        _clock
          ..reset()
          ..start();
        _lastSendMs = 0;
        _sub = gyroscopeEventStream(samplingPeriod: _samplingPeriod).listen(
          _onGyro,
          onError: (Object error) =>
              link.reportProblem('Gyroscope indisponible : $error'),
        );
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

  /// Remet le "zéro" du capteur à zéro (il se réapprend tout seul, téléphone immobile).
  void recalibrate() {
    filter.resetBias();
    notifyListeners();
  }

  void _onGyro(GyroscopeEvent e) {
    final last = _lastStamp;
    _lastStamp = e.timestamp;
    if (last == null) return;
    final dt = e.timestamp.difference(last).inMicroseconds / 1e6;
    if (dt <= 0 || dt > 0.1) return; // mesure aberrante : on ignore

    // Téléphone à plat, bord supérieur vers l'écran : rotation autour de z =
    // horizontal, autour de x = vertical.
    final r = filter.process(-e.z, -e.x, dt);
    _accX += invertX ? -r.dx : r.dx;
    _accY += invertY ? -r.dy : r.dy;

    // On envoie par petits groupes. Le reste fractionnaire (ex. 0,4 px) reste
    // dans l'accumulateur pour l'envoi suivant : aucun petit mouvement n'est perdu.
    final now = _clock.elapsedMilliseconds;
    if (now - _lastSendMs < _sendEveryMs) return;
    _lastSendMs = now;
    final ix = _accX.round();
    final iy = _accY.round();
    if (ix == 0 && iy == 0) return;
    _accX -= ix;
    _accY -= iy;
    link.sendMove(ix, iy);
  }

  @override
  void dispose() {
    link.removeListener(_refresh);
    _laserBeat?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

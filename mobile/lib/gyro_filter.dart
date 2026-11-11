// Le "cerveau" qui transforme la rotation brute du téléphone en pixels propres.
// Aucune dépendance au téléphone ni au réseau : c'est du calcul pur, donc testable.
//
// Trois problèmes, trois réponses :
//
//  1. TREMBLEMENT (la main n'est jamais parfaitement immobile, le capteur non plus)
//     -> lissage "adaptatif" : très fort quand on bouge à peine, quasi nul quand on bouge vite.
//        Image : un amortisseur de voiture ferme sur les petites bosses, souple sur les gros chocs.
//
//  2. RETARD
//     -> le lissage disparaît dès qu'on bouge pour de vrai (c'est le côté "adaptatif"),
//        et on lit le capteur 4 fois plus souvent (voir gyro_pointer.dart).
//
//  3. PRÉCISION SUR LES PETITS MOUVEMENTS
//     -> courbe de gain : à faible vitesse le curseur est démultiplié (comme une vitesse
//        lente sur un levier de précision), à vitesse normale il suit 1 pour 1.
//
// En plus, le "zéro" du capteur n'est jamais exactement zéro (c'est le biais) : sans correction,
// le curseur dérive tout doucement même téléphone posé. On l'apprend en continu quand le
// téléphone est presque immobile, puis on le soustrait.

import 'dart:math' as math;

class GyroFilter {
  /// 0 = peu de lissage (réactif), 1 = lissage maximal (très stable).
  double stability = 0.5;

  /// 0 = courbe linéaire, 1 = très démultiplié sur les petits mouvements.
  double precision = 0.4;

  /// Pixels par radian tourné.
  double sensitivity = 800;

  // Réglages internes (valeurs choisies pour un téléphone tenu à la main).
  static const double _biasLearnBelow =
      0.015; // rad/s : en dessous, on considère "immobile"
  static const double _biasTimeConstant =
      1.0; // s : vitesse d'apprentissage du zéro
  static const double _deadzone =
      0.006; // rad/s : en dessous, on envoie rien (bruit pur)
  static const double _cutoffPerSpeed =
      30; // Hz de plus par rad/s : plus on va vite, moins on lisse
  static const double _curveSpeed =
      0.6; // rad/s : au-delà, plus de démultiplication

  double _biasX = 0, _biasY = 0;
  double _fx = 0, _fy = 0; // vitesse lissée
  bool _started = false;

  /// À appeler quand on commence à pointer : repart sans "mémoire" du geste précédent
  /// (le zéro appris, lui, est conservé).
  void restart() {
    _started = false;
    _fx = 0;
    _fy = 0;
  }

  /// Oublie aussi le zéro appris.
  void resetBias() {
    _biasX = 0;
    _biasY = 0;
    restart();
  }

  double get biasX => _biasX;
  double get biasY => _biasY;

  /// Fréquence de coupure du lissage au repos, en Hz. stability 0 -> 8 Hz, 1 -> 0.8 Hz.
  double get minCutoff =>
      8 * math.pow(0.1, stability.clamp(0.0, 1.0)).toDouble();

  /// [wx], [wy] : vitesses de rotation (rad/s) déjà orientées comme l'écran
  /// (wx > 0 = vers la droite, wy > 0 = vers le bas). [dt] : secondes depuis la mesure précédente.
  /// Renvoie le déplacement en pixels (nombres décimaux : le reste est géré par l'appelant).
  ({double dx, double dy}) process(double wx, double wy, double dt) {
    if (dt <= 0) return (dx: 0, dy: 0);

    // 1. Zéro du capteur : apprentissage lent quand le téléphone est presque immobile.
    if (math.sqrt(math.pow(wx - _biasX, 2) + math.pow(wy - _biasY, 2)) <
        _biasLearnBelow) {
      final k = 1 - math.exp(-dt / _biasTimeConstant);
      _biasX += (wx - _biasX) * k;
      _biasY += (wy - _biasY) * k;
    }
    final cx = wx - _biasX;
    final cy = wy - _biasY;

    // 2. Lissage adaptatif : la coupure monte avec la vitesse.
    if (!_started) {
      _fx = cx;
      _fy = cy;
      _started = true;
    } else {
      final speed = math.sqrt(cx * cx + cy * cy);
      final cutoff = minCutoff + _cutoffPerSpeed * speed;
      final tau = 1 / (2 * math.pi * cutoff);
      final alpha = dt / (dt + tau);
      _fx += alpha * (cx - _fx);
      _fy += alpha * (cy - _fy);
    }

    // 3. Zone morte douce : on retire le bruit résiduel sans créer de "marche" brutale.
    var s = math.sqrt(_fx * _fx + _fy * _fy);
    if (s <= _deadzone) return (dx: 0, dy: 0);
    final live = (s - _deadzone) / s;
    final vx = _fx * live;
    final vy = _fy * live;
    s = s - _deadzone;

    // 4. Courbe de précision : gain réduit à faible vitesse, 1 à vitesse normale.
    final low = 1 -
        0.75 *
            precision.clamp(0.0, 1.0); // gain minimal (précision = 1 -> 0.25)
    final t = (s / _curveSpeed).clamp(0.0, 1.0);
    final gain = low + (1 - low) * (t * t * (3 - 2 * t));

    return (dx: vx * gain * dt * sensitivity, dy: vy * gain * dt * sensitivity);
  }
}

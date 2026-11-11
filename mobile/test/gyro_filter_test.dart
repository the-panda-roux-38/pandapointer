// Vérifie que le filtre fait ce qu'on lui demande : calmer le tremblement,
// annuler la dérive, ne pas retarder un vrai mouvement, démultiplier les petits gestes.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/gyro_filter.dart';

const double dt = 0.005; // 200 mesures par seconde

/// Bruit reproductible (toujours le même) pour des tests qui ne changent pas d'un jour à l'autre.
class Noise {
  int _s = 12345;
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return (_s / 0x7fffffff) * 2 - 1; // entre -1 et 1
  }
}

void main() {
  test('le tremblement est fortement réduit', () {
    final f = GyroFilter()..precision = 0;
    final n = Noise();
    var rawPath = 0.0, outPath = 0.0;
    for (var i = 0; i < 1000; i++) {
      // Main presque immobile : tremblement de +/- 0.05 rad/s (environ 3 degrés par seconde).
      final w = n.next() * 0.05;
      final r = f.process(w, w, dt);
      rawPath += (w * dt * f.sensitivity).abs();
      outPath += r.dx.abs();
    }
    expect(outPath, lessThan(rawPath * 0.35));
  });

  test('la dérive du capteur est apprise puis annulée', () {
    final f = GyroFilter();
    // Téléphone posé : le capteur affiche 0.01 rad/s au lieu de 0.
    var last = 0.0;
    for (var i = 0; i < 1600; i++) {
      // 8 secondes
      last = f.process(0.01, -0.008, dt).dx.abs();
    }
    expect(f.biasX, closeTo(0.01, 0.002));
    expect(last, lessThan(0.01)); // plus de pixels parasites
  });

  test('un vrai mouvement rapide passe presque sans retard', () {
    final f = GyroFilter()
      ..precision = 0
      ..stability = 0.5;
    f.restart();
    var total = 0.0;
    // 0.5 s à 1 rad/s : devrait faire 800 * 1 * 0.5 = 400 pixels.
    for (var i = 0; i < 100; i++) {
      total += f.process(1.0, 0, dt).dx;
    }
    expect(total, greaterThan(400 * 0.95));
    expect(total, lessThan(400 * 1.01));
  });

  test('la précision démultiplie les petits mouvements, pas les grands', () {
    double travel(double precision, double speed) {
      final f = GyroFilter()..precision = precision;
      var total = 0.0;
      for (var i = 0; i < 400; i++) {
        total += f.process(speed, 0, dt).dx;
      }
      return total;
    }

    // Petit mouvement (0.12 rad/s) : plus la précision monte, moins le curseur avance.
    expect(travel(1.0, 0.12), lessThan(travel(0.0, 0.12) * 0.6));
    // Grand mouvement (1.5 rad/s) : la précision ne change presque rien.
    expect(travel(1.0, 1.5), greaterThan(travel(0.0, 1.5) * 0.95));
  });

  test('le sens du mouvement est conservé', () {
    final f = GyroFilter()..precision = 0;
    var x = 0.0, y = 0.0;
    for (var i = 0; i < 100; i++) {
      final r = f.process(-0.8, 0.5, dt);
      x += r.dx;
      y += r.dy;
    }
    expect(x, lessThan(0));
    expect(y, greaterThan(0));
  });

  test('plus de stabilité = plus de calme au repos', () {
    double jitter(double stability) {
      final f = GyroFilter()
        ..stability = stability
        ..precision = 0;
      final n = Noise();
      var p = 0.0;
      for (var i = 0; i < 1000; i++) {
        p += f.process(n.next() * 0.05, 0, dt).dx.abs();
      }
      return p;
    }

    expect(jitter(1.0), lessThan(jitter(0.0)));
  });

  test('dt incohérent ne fait rien de bizarre', () {
    final f = GyroFilter();
    final r = f.process(5, 5, 0);
    expect(r.dx, 0);
    expect(math.sqrt(r.dx * r.dx + r.dy * r.dy), 0);
  });
}

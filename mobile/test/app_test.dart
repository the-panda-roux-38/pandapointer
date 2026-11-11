// Test de fumée : l'appli démarre et les trois onglets s'affichent sans erreur.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/main.dart';

void main() {
  testWidgets('les 3 onglets s\'affichent, le mode gyro continu se règle',
      (tester) async {
    await tester.pumpWidget(const PandaPointerApp());
    expect(find.text('Maintiens pour bouger'), findsOneWidget);

    await tester.tap(find.text('Pavé'));
    await tester.pumpAndSettle();
    expect(find.text('Clic gauche'), findsOneWidget);

    await tester.tap(find.text('Slides'));
    await tester.pumpAndSettle();
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Maintiens pour pointer'), findsOneWidget);

    // Choix du pointeur : curseur par défaut, laser sélectionnable.
    expect(find.text('Curseur'), findsOneWidget);
    await tester.tap(find.text('Laser'));
    await tester.pumpAndSettle();

    // Mode "Toujours" : l'interrupteur apparaît, éteint par défaut.
    await tester.tap(find.text('Toujours'));
    await tester.pumpAndSettle();
    expect(find.text('Pointeur actif'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });
}

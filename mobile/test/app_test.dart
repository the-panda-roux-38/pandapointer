// Tests de l'application complète : écran d'appairage au premier lancement,
// puis les trois onglets une fois appairé.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/main.dart';
import 'package:pandapointer/secure.dart';
import 'package:pandapointer/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('premier lancement : écran d\'appairage, pas de pavé ni de gyro',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PandaPointerApp(autoConnect: false));
    await tester.pumpAndSettle();
    expect(find.text('Appairer ton PC'), findsOneWidget);
    expect(find.text('SCANNER LE QR CODE'), findsOneWidget);
    expect(find.text('GYRO'), findsNothing);

    // Repli sans caméra : coller le lien. Un mauvais lien est refusé avec un message clair.
    await tester.scrollUntilVisible(find.textContaining('COLLER LE LIEN'), 200);
    await tester.tap(find.textContaining('COLLER LE LIEN'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://exemple.fr');
    await tester.scrollUntilVisible(find.text('APPAIRER'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('APPAIRER'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ne ressemble pas'), findsOneWidget);
    expect(find.text('GYRO'), findsNothing); // toujours pas appairé
  });

  testWidgets(
      'appairé : les 3 onglets s\'affichent, le mode gyro continu se règle',
      (tester) async {
    final pairing = Pairing(
        id: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        key: Uint8List.fromList(List.generate(32, (i) => i)),
        pcName: 'PC_PANDA');
    SharedPreferences.setMockInitialValues({});
    await Storage.savePairing(pairing);

    await tester.pumpWidget(const PandaPointerApp(autoConnect: false));
    await tester.pumpAndSettle();
    expect(find.text('MAINTIENS POUR BOUGER'), findsOneWidget);
    expect(find.text('HORS LIGNE'), findsOneWidget);

    await tester.tap(find.text('PAVÉ'));
    await tester.pumpAndSettle();
    expect(find.text('CLIC GAUCHE'), findsOneWidget);

    await tester.tap(find.text('SLIDES'));
    await tester.pumpAndSettle();
    expect(find.text('SUIVANT'), findsOneWidget);
    expect(find.text('Maintiens pour pointer'), findsOneWidget);

    // Choix du pointeur : curseur par défaut, laser sélectionnable.
    expect(find.text('Curseur'), findsOneWidget);
    await tester.tap(find.text('Laser'));
    await tester.pumpAndSettle();

    // Mode "Toujours" : l\'interrupteur apparaît, éteint par défaut.
    await tester.tap(find.text('Toujours'));
    await tester.pumpAndSettle();
    expect(find.text('Pointeur actif'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, false);
  });

  testWidgets(
      'le menu de connexion permet d\'oublier le PC et revient à l\'appairage',
      (tester) async {
    final pairing = Pairing(
        id: Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]),
        key: Uint8List.fromList(List.generate(32, (i) => i)),
        pcName: 'PC_PANDA');
    SharedPreferences.setMockInitialValues({});
    await Storage.savePairing(pairing);
    await tester.pumpWidget(const PandaPointerApp(autoConnect: false));
    await tester.pumpAndSettle();

    await tester.tap(find.text('HORS LIGNE'));
    await tester.pumpAndSettle();
    expect(find.text('PC_PANDA'), findsOneWidget);
    await tester.tap(find.text('OUBLIER CE PC (RÉAPPAIRER)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OUBLIER'));
    await tester.pumpAndSettle();
    expect(find.text('Appairer ton PC'), findsOneWidget);
    expect(await Storage.loadPairing(), isNull);
  });
}

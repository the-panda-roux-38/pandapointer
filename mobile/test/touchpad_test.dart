// Vérifie la logique des gestes du pavé tactile avec de faux doigts.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/link.dart';
import 'package:pandapointer/touchpad_page.dart';

class FakeLink extends Link {
  final List<String> log = [];
  @override
  bool get connected => true;
  @override
  void sendMove(int dx, int dy) => log.add('move');
  @override
  void sendButton(MouseButton b, bool pressed) => log.add('${pressed ? 'down' : 'up'} ${b.name}');
  @override
  void sendClick(MouseButton b) => log.add('click ${b.name}');
  @override
  void sendScroll(int dx, int dy) => log.add('scroll $dx $dy');
  @override
  void sendZoom(int steps) => log.add('zoom $steps');
  @override
  void sendGesture(GestureAction a) => log.add('gesture ${a.name}');
}

void main() {
  Future<FakeLink> pump(WidgetTester tester) async {
    final link = FakeLink();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TouchpadPage(link: link))));
    return link;
  }

  Future<List<TestGesture>> fingers(WidgetTester tester, List<Offset> at) async {
    final list = <TestGesture>[];
    for (final p in at) {
      list.add(await tester.startGesture(p));
    }
    return list;
  }

  /// Fait bouger chaque doigt par petits pas, à tour de rôle (comme de vrais doigts).
  Future<void> move(List<TestGesture> g, List<Offset> totals, {int steps = 10}) async {
    for (var i = 0; i < steps; i++) {
      for (var k = 0; k < g.length; k++) {
        await g[k].moveBy(totals[k] / steps.toDouble());
      }
    }
  }

  Future<void> liftAll(List<TestGesture> g) async {
    for (final f in g) {
      await f.up();
    }
  }

  testWidgets('tap 1 doigt = clic gauche', (tester) async {
    final link = await pump(tester);
    final g = await tester.startGesture(const Offset(200, 200));
    await g.up();
    expect(link.log, ['click left']);
  });

  testWidgets('glisser = déplacer, pas de clic', (tester) async {
    final link = await pump(tester);
    final g = await tester.startGesture(const Offset(200, 200));
    await g.moveBy(const Offset(50, 0));
    await g.up();
    expect(link.log.contains('move'), true);
    expect(link.log.any((e) => e.startsWith('click')), false);
  });

  testWidgets('double-tap = deux clics (double-clic)', (tester) async {
    final link = await pump(tester);
    for (var i = 0; i < 2; i++) {
      final g = await tester.startGesture(const Offset(200, 200));
      await g.up();
    }
    expect(link.log, ['click left', 'click left']);
  });

  testWidgets('double-tap puis glisser = cliquer-glisser', (tester) async {
    final link = await pump(tester);
    final tap = await tester.startGesture(const Offset(200, 200));
    await tap.up();
    final g = await tester.startGesture(const Offset(200, 200));
    await g.moveBy(const Offset(40, 0));
    await g.up();
    expect(link.log.first, 'click left');
    expect(link.log.contains('down left'), true);
    expect(link.log.last, 'up left');
    expect(link.log.indexOf('down left') < link.log.indexOf('up left'), true);
  });

  testWidgets('2 doigts vers le haut = scroll vers le bas', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(150, 300), Offset(250, 300)]);
    await move(g, const [Offset(0, -60), Offset(0, -60)]);
    await liftAll(g);
    final scrolls = link.log.where((e) => e.startsWith('scroll')).toList();
    expect(scrolls.isNotEmpty, true);
    expect(scrolls.every((e) => !e.contains('-')), true); // positif = vers le bas
    expect(link.log.any((e) => e.startsWith('click') || e == 'move' || e.startsWith('zoom')), false);
  });

  testWidgets('2 doigts vers la droite = scroll horizontal vers la gauche (naturel)', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(150, 300), Offset(250, 300)]);
    await move(g, const [Offset(60, 0), Offset(60, 0)]);
    await liftAll(g);
    final scrolls = link.log.where((e) => e.startsWith('scroll')).toList();
    expect(scrolls.isNotEmpty, true);
    expect(scrolls.every((e) => e.startsWith('scroll -')), true);
  });

  testWidgets('écarter 2 doigts = zoom avant', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(190, 300), Offset(210, 300)]);
    await move(g, const [Offset(-40, 0), Offset(40, 0)]);
    await liftAll(g);
    final zooms = link.log.where((e) => e.startsWith('zoom')).toList();
    expect(zooms.isNotEmpty, true);
    expect(zooms.every((e) => !e.contains('-')), true);
    expect(link.log.any((e) => e.startsWith('scroll')), false);
  });

  testWidgets('tap 2 doigts = clic droit', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(150, 300), Offset(250, 300)]);
    await liftAll(g);
    expect(link.log, ['click right']);
  });

  testWidgets('3 doigts vers le haut = vue des tâches', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(100, 300), Offset(180, 300), Offset(260, 300)]);
    await move(g, List.filled(3, const Offset(0, -90)));
    await liftAll(g);
    expect(link.log.where((e) => e.startsWith('gesture')).toList(), ['gesture taskView']);
    expect(link.log.contains('move'), false);
  });

  testWidgets('3 doigts vers la droite = appli suivante', (tester) async {
    final link = await pump(tester);
    final g = await fingers(tester, const [Offset(100, 300), Offset(180, 300), Offset(260, 300)]);
    await move(g, List.filled(3, const Offset(90, 0)));
    await liftAll(g);
    expect(link.log.where((e) => e.startsWith('gesture')).toList(), ['gesture nextApp']);
  });

  testWidgets('4 doigts vers la gauche = bureau virtuel à gauche', (tester) async {
    final link = await pump(tester);
    final g = await fingers(
        tester, const [Offset(60, 300), Offset(120, 300), Offset(180, 300), Offset(240, 300)]);
    await move(g, List.filled(4, const Offset(-90, 0)));
    await liftAll(g);
    expect(link.log.where((e) => e.startsWith('gesture')).toList(), ['gesture desktopLeft']);
  });

  testWidgets('tap 3 doigts = recherche, tap 4 doigts = notifications', (tester) async {
    final link = await pump(tester);
    var g = await fingers(tester, const [Offset(100, 300), Offset(180, 300), Offset(260, 300)]);
    await liftAll(g);
    g = await fingers(
        tester, const [Offset(60, 300), Offset(120, 300), Offset(180, 300), Offset(240, 300)]);
    await liftAll(g);
    expect(link.log, ['gesture search', 'gesture notifications']);
  });
}

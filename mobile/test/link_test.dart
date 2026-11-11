// Vérifie que les octets envoyés sont exactement ceux que le PC attend.
// Les mêmes vecteurs sont testés côté PC (protocol.rs, test shared_vectors_with_phone).

import 'package:flutter_test/flutter_test.dart';
import 'package:pandapointer/link.dart';

void main() {
  test('mouvement', () {
    expect(Packets.move(1, 10, -5), [1, 1, 0, 10, 0, 251, 255]);
  });

  test('bouton enfoncé', () {
    expect(Packets.button(2, MouseButton.left, 1), [2, 2, 0, 1, 1]);
  });

  test('clic droit complet', () {
    expect(Packets.button(3, MouseButton.right, 2), [2, 3, 0, 2, 2]);
  });

  test('scroll horizontal + vertical', () {
    expect(Packets.scroll(4, 2, -3), [3, 4, 0, 2, 0, 253, 255]);
  });

  test('diaporama', () {
    expect(Packets.slide(5, SlideAction.next), [4, 5, 0, 1]);
    expect(Packets.slide(5, SlideAction.previous), [4, 5, 0, 2]);
    expect(Packets.slide(5, SlideAction.start), [4, 5, 0, 3]);
    expect(Packets.slide(5, SlideAction.stop), [4, 5, 0, 4]);
  });

  test('gestes système', () {
    expect(Packets.gesture(6, GestureAction.desktopLeft), [5, 6, 0, 7]);
    expect(Packets.gesture(6, GestureAction.taskView), [5, 6, 0, 1]);
  });

  test('laser', () {
    expect(Packets.laser(8, true), [7, 8, 0, 1]);
    expect(Packets.laser(9, false), [7, 9, 0, 0]);
  });

  test('zoom', () {
    expect(Packets.zoom(7, -3), [6, 7, 0, 253, 255]);
  });
}

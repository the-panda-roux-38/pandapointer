// Onglet "Gyro" : tant que tu maintiens le gros bouton, la rotation du
// téléphone déplace le curseur. La logique est dans gyro_pointer.dart.

import 'package:flutter/material.dart';

import 'gyro_pointer.dart';
import 'link.dart';

class GyroPage extends StatelessWidget {
  const GyroPage({super.key, required this.link, required this.pointer});
  final Link link;
  final GyroPointer pointer;

  Widget _holdArea(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final moving = pointer.holding;
    return Listener(
      onPointerDown: (_) => pointer.holding = true,
      onPointerUp: (_) => pointer.holding = false,
      onPointerCancel: (_) => pointer.holding = false,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: moving ? color.primary : color.primaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        alignment: Alignment.center,
        child: Text(
          moving ? 'Je bouge !' : 'Maintiens pour bouger',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: moving ? color.onPrimary : color.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _clickButton(BuildContext context, String label, MouseButton button) {
    final color = Theme.of(context).colorScheme;
    return Expanded(
      child: Listener(
        onPointerDown: (_) {
          if (link.connected) link.sendButton(button, true);
        },
        onPointerUp: (_) {
          if (link.connected) link.sendButton(button, false);
        },
        onPointerCancel: (_) {
          if (link.connected) link.sendButton(button, false);
        },
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pointer,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _holdArea(context),
          const SizedBox(height: 12),
          Row(children: [
            _clickButton(context, 'Clic gauche', MouseButton.left),
            _clickButton(context, 'Clic droit', MouseButton.right),
          ]),
          const SizedBox(height: 16),
          Text('Sensibilité : ${pointer.sensitivity.round()}'),
          Slider(
            value: pointer.sensitivity,
            min: 200,
            max: 2000,
            onChanged: (v) => pointer.update(() => pointer.sensitivity = v),
          ),
          SwitchListTile(
            title: const Text('Inverser horizontal'),
            value: pointer.invertX,
            onChanged: (v) => pointer.update(() => pointer.invertX = v),
          ),
          SwitchListTile(
            title: const Text('Inverser vertical'),
            value: pointer.invertY,
            onChanged: (v) => pointer.update(() => pointer.invertY = v),
          ),
        ],
      ),
    );
  }
}

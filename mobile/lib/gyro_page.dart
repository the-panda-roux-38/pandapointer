// Onglet "Gyro" : tant que tu maintiens la molette, la rotation du
// téléphone déplace le curseur. La logique est dans gyro_pointer.dart.

import 'package:flutter/material.dart';

import 'gyro_pointer.dart';
import 'link.dart';
import 'theme.dart';
import 'widgets.dart';

class GyroPage extends StatelessWidget {
  const GyroPage({super.key, required this.link, required this.pointer});
  final Link link;
  final GyroPointer pointer;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pointer,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Listener(
              onPointerDown: (_) => pointer.holding = true,
              onPointerUp: (_) => pointer.holding = false,
              onPointerCancel: (_) => pointer.holding = false,
              child: HoldDial(
                active: pointer.holding,
                label: pointer.holding ? 'Je bouge !' : 'Maintiens pour bouger',
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: RaisedKey(
                label: 'CLIC GAUCHE',
                onDown: () => link.sendButton(MouseButton.left, true),
                onUp: () => link.sendButton(MouseButton.left, false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: RaisedKey(
                label: 'CLIC DROIT',
                onDown: () => link.sendButton(MouseButton.right, true),
                onUp: () => link.sendButton(MouseButton.right, false),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          PpPanel(
            child: Column(
              children: [
                SegGauge(
                  label: 'Sensibilité',
                  display: '${pointer.sensitivity.round()}',
                  value: (pointer.sensitivity - 200) / 1800,
                  onChanged: (v) => pointer
                      .update(() => pointer.sensitivity = 200 + v * 1800),
                ),
                SegGauge(
                  label: 'Stabilité',
                  display: '${(pointer.stability * 100).round()} %',
                  value: pointer.stability,
                  onChanged: (v) => pointer.update(() => pointer.stability = v),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Plus la stabilité est haute, moins le curseur tremble quand tu bouges à peine. '
                    'Trop haut, il peut sembler un peu mou sur les mouvements lents.',
                    style: TextStyle(color: Pp.muted, fontSize: 12),
                  ),
                ),
                SegGauge(
                  label: 'Précision',
                  display: '${(pointer.precision * 100).round()} %',
                  value: pointer.precision,
                  onChanged: (v) => pointer.update(() => pointer.precision = v),
                ),
                const Text(
                  'Plus c\'est haut, plus les gestes lents sont démultipliés (on vise au pixel près). '
                  'Les gestes rapides ne changent pas.',
                  style: TextStyle(color: Pp.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PpPanel(
            child: Column(
              children: [
                PpSwitchRow(
                  label: 'Inverser horizontal',
                  value: pointer.invertX,
                  onChanged: (v) => pointer.update(() => pointer.invertX = v),
                ),
                const SizedBox(height: 4),
                PpSwitchRow(
                  label: 'Inverser vertical',
                  value: pointer.invertY,
                  onChanged: (v) => pointer.update(() => pointer.invertY = v),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: pointer.recalibrate,
              child: const Text('RECALIBRER LE ZÉRO DU CAPTEUR'),
            ),
          ),
        ],
      ),
    );
  }
}

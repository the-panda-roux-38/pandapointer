// Onglet "Slides" : télécommande de présentation (PowerPoint, Google Slides, PDF...)
// avec, en option, le gyroscope en pointeur.
//
// Les boutons envoient de simples appuis de touches au PC : flèche droite,
// flèche gauche, F5, Échap. Le diaporama doit donc être la fenêtre active.

import 'package:flutter/material.dart';

import 'gyro_pointer.dart';
import 'link.dart';
import 'theme.dart';
import 'widgets.dart';

class SlidesPage extends StatelessWidget {
  const SlidesPage({super.key, required this.link, required this.pointer});
  final Link link;
  final GyroPointer pointer;

  Widget _pointerCard(BuildContext context) {
    return PpPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSection('Pointeur gyro'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Maintenu')),
                ButtonSegment(value: true, label: Text('Toujours')),
              ],
              selected: {pointer.continuousMode},
              onSelectionChanged: (s) => pointer.setContinuousMode(s.first),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Curseur')),
                ButtonSegment(value: true, label: Text('Laser')),
              ],
              selected: {pointer.laserStyle},
              onSelectionChanged: (s) => pointer.setLaserStyle(s.first),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: pointer.continuousMode
                  ? PpSwitchRow(
                      label: 'Pointeur actif',
                      hint: 'Le curseur suit le téléphone en continu',
                      value: pointer.continuousOn,
                      onChanged: (v) => pointer.continuousOn = v,
                    )
                  : Listener(
                      onPointerDown: (_) => pointer.holding = true,
                      onPointerUp: (_) => pointer.holding = false,
                      onPointerCancel: (_) => pointer.holding = false,
                      child: Container(
                        height: 64,
                        decoration: BoxDecoration(
                          color: pointer.holding ? Pp.accent : Pp.keyBottom,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: pointer.holding ? Pp.accentSoft : Pp.edge),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          pointer.holding
                              ? 'Je pointe !'
                              : 'Maintiens pour pointer',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 1,
                            color: pointer.holding ? Pp.bg : Pp.text,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 88,
              child: RaisedKey(
                label: 'CLIC',
                height: 64,
                onTap: () => link.sendClick(MouseButton.left),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SegGauge(
            label: 'Sensibilité',
            display: '${pointer.sensitivity.round()}',
            value: (pointer.sensitivity - 200) / 1800,
            onChanged: (v) =>
                pointer.update(() => pointer.sensitivity = 200 + v * 1800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pointer,
      // Suivant / Précédent restent toujours visibles en bas (c'est ce qu'on presse le plus) ;
      // les réglages au-dessus défilent si l'écran est petit.
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                        child: RaisedKey(
                          label: 'DÉMARRER',
                          icon: 'play',
                          height: 56,
                          onTap: () => link.sendSlide(SlideAction.start),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RaisedKey(
                          label: 'QUITTER',
                          icon: 'cross',
                          height: 56,
                          onTap: () => link.sendSlide(SlideAction.stop),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _pointerCard(context),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            RaisedKey(
              label: 'SUIVANT',
              icon: 'arrow_right',
              accent: true,
              height: 112,
              onTap: () => link.sendSlide(SlideAction.next),
            ),
            const SizedBox(height: 8),
            RaisedKey(
              label: 'PRÉCÉDENT',
              icon: 'arrow_left',
              height: 64,
              onTap: () => link.sendSlide(SlideAction.previous),
            ),
          ],
        ),
      ),
    );
  }
}

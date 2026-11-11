// Onglet "Slides" : télécommande de présentation (PowerPoint, Google Slides, PDF...)
// avec, en option, le gyroscope en pointeur.
//
// Les boutons envoient de simples appuis de touches au PC : flèche droite,
// flèche gauche, F5, Échap. Le diaporama doit donc être la fenêtre active.

import 'package:flutter/material.dart';

import 'gyro_pointer.dart';
import 'link.dart';

class SlidesPage extends StatelessWidget {
  const SlidesPage({super.key, required this.link, required this.pointer});
  final Link link;
  final GyroPointer pointer;

  Widget _big(String label, IconData icon, SlideAction action, Color bg,
      Color fg, int flex) {
    return Expanded(
      flex: flex,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => link.sendSlide(action),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 40, color: fg),
                  const SizedBox(width: 12),
                  Text(label,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pointerCard(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.screen_rotation, size: 20),
              const SizedBox(width: 8),
              const Text('Pointeur gyro',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: const [
                  ButtonSegment(value: false, label: Text('Maintenu')),
                  ButtonSegment(value: true, label: Text('Toujours')),
                ],
                selected: {pointer.continuousMode},
                onSelectionChanged: (s) => pointer.setContinuousMode(s.first),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Pointeur :'),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  style:
                      const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(
                        value: false,
                        icon: Icon(Icons.mouse, size: 18),
                        label: Text('Curseur')),
                    ButtonSegment(
                        value: true,
                        icon: Icon(Icons.flashlight_on, size: 18),
                        label: Text('Laser')),
                  ],
                  selected: {pointer.laserStyle},
                  onSelectionChanged: (s) => pointer.setLaserStyle(s.first),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: pointer.continuousMode
                    ? SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Pointeur actif'),
                        subtitle: const Text(
                            'Le curseur suit le téléphone en continu'),
                        value: pointer.continuousOn,
                        onChanged: (v) => pointer.continuousOn = v,
                      )
                    : Listener(
                        onPointerDown: (_) => pointer.holding = true,
                        onPointerUp: (_) => pointer.holding = false,
                        onPointerCancel: (_) => pointer.holding = false,
                        child: Container(
                          height: 72,
                          decoration: BoxDecoration(
                            color: pointer.holding
                                ? color.primary
                                : color.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            pointer.holding
                                ? 'Je pointe !'
                                : 'Maintiens pour pointer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: pointer.holding
                                  ? color.onPrimary
                                  : color.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => link.sendClick(MouseButton.left),
                style: FilledButton.styleFrom(minimumSize: const Size(72, 72)),
                child: const Text('Clic'),
              ),
            ]),
            Text('Sensibilité : ${pointer.sensitivity.round()}',
                style: Theme.of(context).textTheme.bodySmall),
            Slider(
              value: pointer.sensitivity,
              min: 200,
              max: 2000,
              onChanged: (v) => pointer.update(() => pointer.sensitivity = v),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: pointer,
      // Défilant : sur un petit écran la page se fait défiler au lieu de déborder ;
      // sur un grand, les gros boutons Suivant/Précédent occupent la place restante.
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight - 32),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => link.sendSlide(SlideAction.start),
                        icon: const Icon(Icons.slideshow),
                        label: const Text('Démarrer (F5)'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => link.sendSlide(SlideAction.stop),
                        icon: const Icon(Icons.close),
                        label: const Text('Quitter (Échap)'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  _pointerCard(context),
                  const SizedBox(height: 12),
                  _big('Suivant', Icons.arrow_forward, SlideAction.next,
                      color.primary, color.onPrimary, 3),
                  const SizedBox(height: 12),
                  _big('Précédent', Icons.arrow_back, SlideAction.previous,
                      color.secondaryContainer, color.onSecondaryContainer, 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

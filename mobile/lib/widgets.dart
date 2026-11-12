// Les pièces de l'interface : touche-bloc, pavé de maintien, jauge à segments, interrupteur carré,
// panda, quadrillage. Tout est rectangulaire et plat (voir theme.dart).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Icône Papicons (assets/icons/<nom>.svg), teintée à la couleur voulue.
class PpIcon extends StatelessWidget {
  const PpIcon(this.name, {super.key, this.size = 22, this.color = Pp.text});
  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        excludeFromSemantics: true,
      );
}

/// Le panda roux (le même que dans Coche et sur le site).
class PandaMark extends StatelessWidget {
  const PandaMark({super.key, this.width = 40});
  final double width;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brand/panda.svg',
        width: width,
        excludeFromSemantics: true,
      );
}

/// Petit titre de section, en lettres espacées.
class PpSection extends StatelessWidget {
  const PpSection(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: ppLabel());
}

/// Bloc de réglages : aplat, contour net.
class PpPanel extends StatelessWidget {
  const PpPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Pp.panel,
          border: Border.all(color: Pp.edge, width: 2),
        ),
        child: child,
      );
}

/// Touche en forme de bloc : une face et un flanc dessous, comme un cube vu de côté.
/// Réagit dès que le doigt se pose (important pour maintenir un clic).
/// - [onTap] : appelé au relâchement (une touche « simple »).
/// - [onDown] / [onUp] : pour les touches qu'on maintient (clic maintenu, glisser-déposer).
class RaisedKey extends StatefulWidget {
  const RaisedKey({
    super.key,
    required this.label,
    this.icon,
    this.height = 68,
    this.accent = false,
    this.onTap,
    this.onDown,
    this.onUp,
  });
  final String label;
  final String? icon;
  final double height;
  final bool accent;
  final VoidCallback? onTap;
  final VoidCallback? onDown;
  final VoidCallback? onUp;

  @override
  State<RaisedKey> createState() => _RaisedKeyState();
}

class _RaisedKeyState extends State<RaisedKey> {
  bool _down = false;
  static const _side = 6.0;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final face = widget.accent ? Pp.accent : Pp.keyTop;
    final side = widget.accent ? Pp.accentDeep : Pp.depth;
    final line = widget.accent ? Pp.accentDeep : Pp.edge;
    final sink = _down ? _side - 2 : 0.0;
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      child: ExcludeSemantics(
        child: Listener(
          onPointerDown: (_) {
            _set(true);
            widget.onDown?.call();
          },
          onPointerUp: (_) {
            _set(false);
            widget.onUp?.call();
            widget.onTap?.call();
          },
          onPointerCancel: (_) {
            _set(false);
            widget.onUp?.call();
          },
          child: SizedBox(
            height: widget.height + _side,
            child: Stack(
              children: [
                // flanc du bloc
                Positioned(
                  left: 0,
                  right: 0,
                  top: _side,
                  height: widget.height,
                  child: ColoredBox(color: side),
                ),
                // face du bloc
                Positioned(
                  left: 0,
                  right: 0,
                  top: sink,
                  height: widget.height,
                  child: Container(
                    decoration: BoxDecoration(
                      color: face,
                      border: Border.all(color: line, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          PpIcon(widget.icon!, size: 22, color: Pp.text),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: Pp.display,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 1.6,
                              color: Pp.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le grand carré qu'on maintient pour bouger (ou pointer). Il devient roux quand [active].
/// Quatre équerres dans les coins : un viseur.
class HoldDial extends StatelessWidget {
  const HoldDial({
    super.key,
    required this.active,
    required this.label,
    this.size = 250,
  });
  final bool active;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    const side = 8.0;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size + side,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: side,
                width: size,
                height: size,
                child: ColoredBox(color: active ? Pp.accentDeep : Pp.depth),
              ),
              Positioned(
                left: 0,
                top: active ? side - 3 : 0,
                width: size,
                height: size,
                child: Container(
                  decoration: BoxDecoration(
                    color: active ? Pp.accent : Pp.panel,
                    border: Border.all(
                        color: active ? Pp.accentDeep : Pp.edge, width: 3),
                  ),
                  child: CustomPaint(
                    painter: _ViewfinderPainter(active ? Pp.text : Pp.accent),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: size * 0.4,
                          height: size * 0.4,
                          child: CustomPaint(
                              painter: _MoveGlyphPainter(
                                  active ? Pp.text : Pp.accent)),
                        ),
                        SizedBox(height: size * 0.06),
                        Text(label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: ppLabel(
                                    color: active ? Pp.text : Pp.muted,
                                    size: 13)
                                .copyWith(letterSpacing: 2)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quatre équerres dans les coins du carré.
class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.butt;
    const inset = 16.0, arm = 22.0;
    final w = size.width, h = size.height;
    void corner(double x, double y, double dx, double dy) {
      canvas.drawLine(Offset(x, y), Offset(x + dx * arm, y), p);
      canvas.drawLine(Offset(x, y), Offset(x, y + dy * arm), p);
    }

    corner(inset, inset, 1, 1);
    corner(w - inset, inset, -1, 1);
    corner(inset, h - inset, 1, -1);
    corner(w - inset, h - inset, -1, -1);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.color != color;
}

/// Croix à quatre flèches (« déplacer »), traits francs, sans bouts arrondis.
class _MoveGlyphPainter extends CustomPainter {
  _MoveGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final a = size.width * 0.12;
    for (var i = 0; i < 4; i++) {
      final ang = i * math.pi / 2;
      final d = Offset(math.cos(ang), math.sin(ang));
      final n = Offset(-d.dy, d.dx);
      canvas.drawLine(c, c + d * r, p);
      final tip = c + d * r;
      canvas.drawLine(tip, tip - d * a + n * a, p);
      canvas.drawLine(tip, tip - d * a - n * a, p);
    }
  }

  @override
  bool shouldRepaint(_MoveGlyphPainter old) => old.color != color;
}

/// Quadrillage discret (des cases, comme un monde en cubes) : donne du grain sans dégradé.
class PpGrid extends CustomPainter {
  const PpGrid({this.step = 28, this.color = const Color(0x14F8F1E6)});
  final double step;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(PpGrid old) => old.step != step || old.color != color;
}

/// Jauge à segments : on touche ou on glisse pour régler. [value] va de 0 à 1.
class SegGauge extends StatelessWidget {
  const SegGauge({
    super.key,
    required this.label,
    required this.display,
    required this.value,
    required this.onChanged,
    this.segments = 10,
  });
  final String label;
  final String display;
  final double value;
  final ValueChanged<double> onChanged;
  final int segments;

  @override
  Widget build(BuildContext context) {
    final lit = (value.clamp(0.0, 1.0) * segments).round();
    void setFrom(double dx, double width) {
      final n = ((dx / width) * segments).ceil().clamp(0, segments);
      onChanged(n / segments);
    }

    return Semantics(
      label: label,
      value: display,
      increasedValue: display,
      decreasedValue: display,
      onIncrease: () => onChanged((value + 1 / segments).clamp(0.0, 1.0)),
      onDecrease: () => onChanged((value - 1 / segments).clamp(0.0, 1.0)),
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(), style: ppLabel()),
                Text(display, style: ppMono(size: 14)),
              ],
            ),
            LayoutBuilder(
              builder: (context, box) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => setFrom(d.localPosition.dx, box.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    setFrom(d.localPosition.dx, box.maxWidth),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      for (var i = 0; i < segments; i++)
                        Expanded(
                          child: Container(
                            height: 18,
                            margin: EdgeInsets.only(
                                right: i == segments - 1 ? 0 : 3),
                            color: i < lit ? Pp.accent : Pp.segOff,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interrupteur carré : un rail rectangulaire et un bloc qui glisse.
class PpToggle extends StatelessWidget {
  const PpToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: SizedBox(
            width: 64,
            height: 48,
            child: Center(
              child: Container(
                width: 56,
                height: 30,
                decoration: BoxDecoration(
                  color: value ? Pp.accent : Pp.panel,
                  border: Border.all(
                      color: value ? Pp.accentDeep : Pp.edge, width: 2),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 90),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: value ? Pp.text : Pp.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Ligne « texte + interrupteur ».
class PpSwitchRow extends StatelessWidget {
  const PpSwitchRow(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.hint});
  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  if (hint != null)
                    Text(hint!,
                        style: const TextStyle(color: Pp.muted, fontSize: 12)),
                ],
              ),
            ),
            PpToggle(value: value, onChanged: onChanged),
          ],
        ),
      );
}

/// Section repliable (à la place du menu déroulant standard) : titre + petite flèche carrée.
class PpCollapse extends StatefulWidget {
  const PpCollapse({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  State<PpCollapse> createState() => _PpCollapseState();
}

class _PpCollapseState extends State<PpCollapse> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            label: widget.title,
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: SizedBox(
                  height: 52,
                  child: Row(children: [
                    Expanded(child: Text(widget.title, style: ppLabel())),
                    RotatedBox(
                      quarterTurns: _open ? 3 : 1,
                      child: PpIcon('arrow_right',
                          size: 22, color: _open ? Pp.accent : Pp.muted),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          if (_open) ...widget.children,
        ],
      );
}

/// Pastille de statut, carrée : vert = en ligne, jaune = connexion en cours, gris = éteint.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 10, height: 10, color: color);
}

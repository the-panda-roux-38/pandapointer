// Les pièces de la télécommande : touche en relief, molette concave, jauge à segments, icônes.

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

/// Petit titre de section, en lettres espacées.
class PpSection extends StatelessWidget {
  const PpSection(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: ppLabel());
}

/// Panneau de réglages arrondi.
class PpPanel extends StatelessWidget {
  const PpPanel({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Pp.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2B211B)),
        ),
        child: child,
      );
}

/// Touche en relief. Réagit dès que le doigt se pose (important pour maintenir un clic).
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

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.accent ? Pp.bg : Pp.text;
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
            height: widget.height + 6,
            child: Align(
              alignment: Alignment.topCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 60),
                margin: EdgeInsets.only(top: _down ? 4 : 0),
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.accent
                        ? const [Pp.accentSoft, Pp.accent]
                        : const [Pp.keyTop, Pp.keyBottom],
                  ),
                  border: Border(
                    top: BorderSide(
                        color:
                            widget.accent ? const Color(0xFFFFB08E) : Pp.edge),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Pp.depth, offset: Offset(0, _down ? 1 : 5)),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      PpIcon(widget.icon!, size: 22, color: fg),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Pp.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: 2,
                          color: fg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La grosse molette concave : on la maintient pour bouger (ou pointer).
/// Elle s'allume quand [active].
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
    final inner = size * 0.6;
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              colors: [Color(0xFF3A2D25), Color(0xFF1E1713)],
            ),
            boxShadow: [
              const BoxShadow(color: Pp.depth, offset: Offset(0, 10)),
              BoxShadow(
                  color: active ? Pp.accent : const Color(0xFF241C17),
                  spreadRadius: 8),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: inner,
                height: inner,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Pp.accent.withAlpha(60) : Colors.transparent,
                  border: Border.all(color: Pp.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: Pp.accent.withAlpha(active ? 140 : 60),
                        blurRadius: active ? 34 : 22),
                  ],
                ),
                child: CustomPaint(painter: _MoveGlyphPainter(Pp.accent)),
              ),
              SizedBox(height: size * 0.04),
              Text(label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: ppLabel(color: const Color(0xFFC9B5A4), size: 13)
                      .copyWith(letterSpacing: 3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Croix à quatre flèches (« déplacer »).
class _MoveGlyphPainter extends CustomPainter {
  _MoveGlyphPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final c = size.center(Offset.zero);
    final r = size.width * 0.24;
    final a = size.width * 0.06;
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
                Text(display, style: ppMono()),
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
                            height: 16,
                            margin: EdgeInsets.only(
                                right: i == segments - 1 ? 0 : 3),
                            decoration: BoxDecoration(
                              color: i < lit ? Pp.accent : Pp.segOff,
                              borderRadius: BorderRadius.circular(2),
                            ),
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
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      );
}

/// Point de statut : vert = en ligne, orange = connexion en cours, gris = éteint.
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, this.glow = true});
  final Color color;
  final bool glow;
  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: glow ? [BoxShadow(color: color, blurRadius: 8)] : null,
        ),
      );
}

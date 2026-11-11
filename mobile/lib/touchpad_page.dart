// Onglet "Pavé" : le téléphone devient un touchpad de portable Windows.
//
//   1 doigt  : glisser = curseur (avec accélération) · tap = clic gauche
//              double-tap puis glisser = cliquer-glisser · double-tap = double-clic
//   2 doigts : glisser = scroll vertical + horizontal (avec inertie)
//              pincer / écarter = zoom (Ctrl + molette) · tap = clic droit
//   3 doigts : balayer haut = vue des tâches · bas = bureau
//              gauche/droite = changer d'appli · tap = recherche
//   4 doigts : balayer gauche/droite = changer de bureau virtuel · tap = notifications

import 'dart:async';

import 'package:flutter/material.dart';

import 'link.dart';

class TouchpadPage extends StatefulWidget {
  const TouchpadPage({super.key, required this.link});
  final Link link;

  @override
  State<TouchpadPage> createState() => _TouchpadPageState();
}

enum _TwoFingerMode { undecided, scroll, pinch }

class _TouchpadPageState extends State<TouchpadPage> {
  // ---- Réglages
  double _speed = 1.6; // vitesse de base du curseur
  double _accel = 0.6; // 0 = linéaire, 1 = très accéléré
  bool _naturalScroll =
      true; // doigts vers le haut = la page monte (comme un téléphone)

  // ---- Constantes des gestes
  static const double _tapMaxTravel =
      12; // au-delà : c'est un glissement, pas un tap
  static const Duration _tapMaxTime = Duration(milliseconds: 250);
  static const Duration _doubleTapGap = Duration(milliseconds: 300);
  static const double _dragStartTravel = 4; // distance avant de cliquer-glisser
  static const double _pxPerScrollClick =
      16; // distance de doigts pour un cran de molette
  static const double _pxPerZoomStep =
      30; // variation d'écartement pour un cran de zoom
  static const double _modeLockTravel =
      14; // distance avant de choisir scroll ou zoom
  static const double _swipeTravel =
      70; // distance pour valider un balayage 3/4 doigts

  // ---- Doigts posés
  final Map<int, Offset> _fingers = {};
  Offset _prevCentroid = Offset.zero;
  double _prevDist = 0;
  Duration? _lastMoveStamp;

  // ---- Geste en cours (remis à zéro quand tous les doigts sont levés)
  int _maxFingers = 0;
  DateTime _startedAt = DateTime.now();
  double _travel = 0; // distance totale parcourue (centre des doigts)
  double _remX = 0, _remY = 0; // reste fractionnaire du curseur

  // cliquer-glisser
  DateTime? _lastTapUp;
  bool _dragMode = false; // ce geste suit un tap : un glissé = cliquer-glisser
  bool _buttonDown = false;

  // 2 doigts
  _TwoFingerMode _mode = _TwoFingerMode.undecided;
  double _panAbs = 0; // chemin parcouru par le centre des doigts
  double _pinchNet =
      0; // variation NETTE de l'écartement (signée : un doigt qui bouge avant l'autre s'annule)
  double _scrollAccX = 0, _scrollAccY = 0, _zoomAcc = 0;
  double _velX = 0, _velY = 0; // vitesse de scroll (px/s), pour l'inertie
  DateTime _lastScrollMove = DateTime.now();
  Timer? _inertia;

  // 3-4 doigts
  Offset _swipe = Offset.zero;
  bool _swipeFired = false;

  Link get _link => widget.link;

  @override
  void dispose() {
    _inertia?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------------ outils

  void _rebase() {
    if (_fingers.isEmpty) return;
    _prevCentroid = _centroid();
    _prevDist = _fingers.length == 2 ? _spread() : 0;
  }

  Offset _centroid() {
    var sum = Offset.zero;
    for (final p in _fingers.values) {
      sum += p;
    }
    return sum / _fingers.length.toDouble();
  }

  double _spread() {
    final pts = _fingers.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  void _stopInertia() {
    _inertia?.cancel();
    _inertia = null;
  }

  void _releaseButtonIfNeeded() {
    if (_buttonDown) {
      _link.sendButton(MouseButton.left, false);
      _buttonDown = false;
    }
  }

  // ------------------------------------------------------------------- doigts

  void _onDown(PointerDownEvent e) {
    _stopInertia();
    if (_fingers.isEmpty) {
      final now = DateTime.now();
      _maxFingers = 0;
      _travel = 0;
      _remX = 0;
      _remY = 0;
      _mode = _TwoFingerMode.undecided;
      _panAbs = _pinchNet = 0;
      _scrollAccX = _scrollAccY = _zoomAcc = 0;
      _velX = _velY = 0;
      _swipe = Offset.zero;
      _swipeFired = false;
      _lastMoveStamp = null;
      _startedAt = now;
      final last = _lastTapUp;
      _dragMode = last != null && now.difference(last) < _doubleTapGap;
    }
    _fingers[e.pointer] = e.localPosition;
    if (_fingers.length > _maxFingers) _maxFingers = _fingers.length;
    if (_maxFingers > 1) {
      // Plusieurs doigts : ce n'est plus un cliquer-glisser.
      _dragMode = false;
      _releaseButtonIfNeeded();
    }
    _rebase();
    setState(() {});
  }

  void _onMove(PointerMoveEvent e) {
    final previous = _fingers[e.pointer];
    if (previous == null) return;
    _fingers[e.pointer] = e.localPosition;
    final n = _fingers.length;

    // Temps écoulé depuis le dernier mouvement (pour estimer la vitesse du doigt).
    final stamp = e.timeStamp;
    final dtMs = _lastMoveStamp == null
        ? 16.0
        : (stamp - _lastMoveStamp!).inMicroseconds.clamp(1000, 100000) / 1000.0;
    _lastMoveStamp = stamp;

    if (!_link.connected) {
      _rebase();
      return;
    }

    if (n == 1 && _maxFingers == 1) {
      _onOneFinger(e.localPosition - previous, dtMs);
      return;
    }
    if (n != _maxFingers) {
      _rebase(); // un doigt vient de se lever : on repart de zéro, sans à-coup
      return;
    }

    // 2 doigts ou plus : on suit le centre des doigts (et l'écartement à 2 doigts).
    final c = _centroid();
    final delta = c - _prevCentroid;
    _prevCentroid = c;
    _travel += delta.distance;

    if (n == 2) {
      final d = _spread();
      final dd = d - _prevDist;
      _prevDist = d;
      _onTwoFingers(delta, dd, dtMs);
    } else {
      _onSwipe(delta);
    }
  }

  // ------------------------------------------------------------- 1 doigt

  void _onOneFinger(Offset delta, double dtMs) {
    _travel += delta.distance;

    // Double-tap puis glisser : on enfonce le bouton gauche dès que ça bouge.
    if (_dragMode && !_buttonDown && _travel > _dragStartTravel) {
      _link.sendButton(MouseButton.left, true);
      _buttonDown = true;
    }

    // Accélération : plus le doigt va vite, plus le curseur va loin.
    final speed = delta.distance / dtMs; // px par ms
    final gain = _speed * (1 + _accel * (speed.clamp(0.0, 3.0) * 0.5 - 0.3));
    final dx = delta.dx * gain + _remX;
    final dy = delta.dy * gain + _remY;
    final ix = dx.round();
    final iy = dy.round();
    _remX = dx - ix;
    _remY = dy - iy;
    if (ix != 0 || iy != 0) _link.sendMove(ix, iy);
  }

  // ------------------------------------------------------------ 2 doigts

  void _onTwoFingers(Offset delta, double dd, double dtMs) {
    final dir = _naturalScroll
        ? -1.0
        : 1.0; // doigts vers le haut -> défiler vers le bas
    _panAbs += delta.distance;
    _pinchNet += dd;
    _scrollAccX += delta.dx * dir;
    _scrollAccY += delta.dy * dir;
    _zoomAcc += dd;

    if (_mode == _TwoFingerMode.undecided) {
      if (_panAbs + _pinchNet.abs() < _modeLockTravel) return;
      // Écartement qui varie nettement plus que le centre ne bouge : zoom.
      // (Valeur nette : quand les doigts glissent ensemble, l'écartement bouge un instant
      // puis revient, et ça s'annule ; en pincement, ça s'additionne.)
      _mode = _pinchNet.abs() > _panAbs * 1.2
          ? _TwoFingerMode.pinch
          : _TwoFingerMode.scroll;
      if (_mode == _TwoFingerMode.pinch) {
        _scrollAccX = _scrollAccY = 0;
      } else {
        _zoomAcc = 0;
      }
    }

    if (_mode == _TwoFingerMode.scroll) {
      // Vitesse lissée, pour l'inertie au moment où on lève les doigts.
      final secs = dtMs / 1000;
      _velX = _velX * 0.6 + (delta.dx * dir / secs) * 0.4;
      _velY = _velY * 0.6 + (delta.dy * dir / secs) * 0.4;
      _lastScrollMove = DateTime.now();
      _flushScroll();
    } else {
      final steps = (_zoomAcc / _pxPerZoomStep).truncate();
      if (steps != 0) {
        _zoomAcc -= steps * _pxPerZoomStep;
        _link.sendZoom(steps); // écarter = zoom avant
      }
    }
  }

  /// Transforme les pixels accumulés en crans de molette entiers.
  void _flushScroll() {
    final cx = (_scrollAccX / _pxPerScrollClick).truncate();
    final cy = (_scrollAccY / _pxPerScrollClick).truncate();
    if (cx != 0 || cy != 0) {
      _scrollAccX -= cx * _pxPerScrollClick;
      _scrollAccY -= cy * _pxPerScrollClick;
      _link.sendScroll(cx, cy);
    }
  }

  void _startInertia() {
    // Seulement si les doigts allaient vite et viennent juste de se lever.
    final fresh =
        DateTime.now().difference(_lastScrollMove).inMilliseconds < 80;
    if (!fresh || (_velX.abs() < 250 && _velY.abs() < 250)) return;
    _inertia = Timer.periodic(const Duration(milliseconds: 16), (t) {
      _velX *= 0.94;
      _velY *= 0.94;
      _scrollAccX += _velX * 0.016;
      _scrollAccY += _velY * 0.016;
      _flushScroll();
      if (_velX.abs() < 40 && _velY.abs() < 40) _stopInertia();
    });
  }

  // ---------------------------------------------------------- 3-4 doigts

  void _onSwipe(Offset delta) {
    _swipe += delta;
    if (_swipeFired || _swipe.distance < _swipeTravel) return;
    _swipeFired = true;
    final horizontal = _swipe.dx.abs() > _swipe.dy.abs();
    final right = _swipe.dx > 0;
    final down = _swipe.dy > 0;
    if (_maxFingers == 3) {
      if (horizontal) {
        _link.sendGesture(
            right ? GestureAction.nextApp : GestureAction.previousApp);
      } else {
        _link.sendGesture(
            down ? GestureAction.showDesktop : GestureAction.taskView);
      }
    } else if (_maxFingers >= 4 && horizontal) {
      _link.sendGesture(
          right ? GestureAction.desktopRight : GestureAction.desktopLeft);
    } else if (_maxFingers >= 4) {
      _link.sendGesture(
          down ? GestureAction.showDesktop : GestureAction.taskView);
    }
  }

  // -------------------------------------------------------------- fin du geste

  void _onUp(PointerEvent e) {
    _fingers.remove(e.pointer);
    if (_fingers.isNotEmpty) {
      _rebase();
      setState(() {});
      return;
    }

    // Tous les doigts sont levés : que s'est-il passé ?
    final quick = DateTime.now().difference(_startedAt) < _tapMaxTime;
    final isTap = quick && _travel < _tapMaxTravel && e is PointerUpEvent;

    if (_buttonDown) {
      _releaseButtonIfNeeded(); // fin d'un cliquer-glisser
      _lastTapUp = null;
    } else if (_link.connected) {
      switch (_maxFingers) {
        case 1:
          if (isTap) {
            _link.sendClick(MouseButton.left);
            // Un 1er tap ouvre la fenêtre du double-tap ; le 2e la referme.
            _lastTapUp = _dragMode ? null : DateTime.now();
          } else {
            _lastTapUp = null;
          }
        case 2:
          if (isTap) _link.sendClick(MouseButton.right);
          if (_mode == _TwoFingerMode.scroll) _startInertia();
          _lastTapUp = null;
        case 3:
          if (isTap) _link.sendGesture(GestureAction.search);
          _lastTapUp = null;
        case 4:
          if (isTap) _link.sendGesture(GestureAction.notifications);
          _lastTapUp = null;
        default:
          _lastTapUp = null;
      }
    }
    _maxFingers = 0;
    _dragMode = false;
    setState(() {});
  }

  // ---------------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final active = _fingers.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onUp,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: active
                      ? color.primaryContainer
                      : color.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    active
                        ? '${_fingers.length} doigt${_fingers.length > 1 ? 's' : ''}'
                        : '1 doigt : bouger · tap = clic\n'
                            'double-tap + glisser = cliquer-glisser\n\n'
                            '2 doigts : scroll · pincer = zoom\n'
                            'tap = clic droit\n\n'
                            '3 doigts : balayer = vue des tâches, bureau, appli\n'
                            '4 doigts : balayer = changer de bureau',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color.onSurfaceVariant,
                      fontSize: active ? 28 : 15,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => _link.sendClick(MouseButton.left),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Clic gauche'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => _link.sendClick(MouseButton.right),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Clic droit'),
                ),
              ),
            ),
          ]),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Réglages du pavé'),
            children: [
              Row(children: [
                SizedBox(
                    width: 110,
                    child: Text('Vitesse ${_speed.toStringAsFixed(1)}')),
                Expanded(
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 4,
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                ),
              ]),
              Row(children: [
                SizedBox(
                    width: 110,
                    child: Text('Accélération ${(_accel * 100).round()}%')),
                Expanded(
                  child: Slider(
                    value: _accel,
                    min: 0,
                    max: 1,
                    onChanged: (v) => setState(() => _accel = v),
                  ),
                ),
              ]),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Scroll naturel'),
                subtitle: const Text('Doigts vers le haut = la page monte'),
                value: _naturalScroll,
                onChanged: (v) => setState(() => _naturalScroll = v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

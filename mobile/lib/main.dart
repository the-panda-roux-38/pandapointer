// PandaPointer, côté téléphone.
//
// Au premier lancement : appairage avec le PC (QR code). Ensuite : trois onglets (Gyro, Pavé,
// Slides) qui partagent la même liaison chiffrée. La liaison se rétablit toute seule.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'discovery.dart';
import 'gyro_page.dart';
import 'gyro_pointer.dart';
import 'link.dart';
import 'pairing_page.dart';
import 'secure.dart';
import 'slides_page.dart';
import 'storage.dart';
import 'theme.dart';
import 'touchpad_page.dart';
import 'widgets.dart';

void main() => runApp(const PandaPointerApp());

class PandaPointerApp extends StatelessWidget {
  const PandaPointerApp({super.key, this.autoConnect = true});

  /// Faux dans les tests : pas de recherche réseau automatique au démarrage.
  final bool autoConnect;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PandaPointer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomePage(autoConnect: autoConnect),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.autoConnect = true});
  final bool autoConnect;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final Link _link = Link();
  late final GyroPointer _pointer = GyroPointer(_link);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _ip = TextEditingController();

  bool _loaded = false;
  Pairing? _pairing;
  bool _searching = false;
  String? _savedIp;

  @override
  void initState() {
    super.initState();
    // Le mode "toujours actif" du gyro n'a de sens que sur l'onglet Slides.
    _tabs.addListener(() => _pointer.slidesMode = _tabs.index == 2);
    _link.findPc = _findPcByName;
    _link.addListener(_rememberAddress);
    _load();
  }

  @override
  void dispose() {
    _link.removeListener(_rememberAddress);
    _tabs.dispose();
    _pointer.dispose();
    _link.dispose();
    _ip.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final pairing = await Storage.loadPairing();
    final ip = await Storage.loadLastIp();
    if (!mounted) return;
    setState(() {
      _pairing = pairing;
      _loaded = true;
      _savedIp = ip;
      if (ip != null) _ip.text = ip;
    });
    _link.setPairing(pairing);
    if (pairing != null && widget.autoConnect) _autoConnect();
  }

  /// Au lancement : on retente la dernière adresse ; sinon on cherche le PC sur le réseau.
  Future<void> _autoConnect() async {
    if (_savedIp != null) {
      await _link.connect(_savedIp!);
    } else {
      await _search(auto: true);
    }
  }

  /// Retient l'adresse du PC dès que la liaison fonctionne (pour la reprise automatique).
  void _rememberAddress() {
    final ip = _link.address;
    if (_link.online && ip != null && ip != _savedIp) {
      _savedIp = ip;
      Storage.saveLastIp(ip);
    }
  }

  Future<String?> _findPcByName(String name) async {
    try {
      final pcs = await discoverPcs();
      for (final pc in pcs) {
        if (pc.name == name) return pc.address.address;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _onPaired(Pairing pairing) async {
    await Storage.savePairing(pairing);
    _link.setPairing(pairing);
    if (!mounted) return;
    setState(() => _pairing = pairing);
    final ip = pairing.ip;
    if (ip != null) {
      // Le QR code donne l'adresse du PC : on y va tout droit, sans chercher.
      _snack('Appairé avec ${pairing.pcName}. Connexion...');
      _savedIp = ip;
      Storage.saveLastIp(ip);
      await _link.connect(ip);
      await Future<void>.delayed(const Duration(seconds: 4));
      if (!mounted || _link.online) return;
    } else {
      _snack('Appairé avec ${pairing.pcName}. Je cherche le PC...');
    }
    await _search(auto: true);
  }

  Future<void> _forget() async {
    _link.disconnect();
    await Storage.forgetPairing();
    _link.setPairing(null);
    if (!mounted) return;
    setState(() {
      _pairing = null;
      _savedIp = null;
      _ip.clear();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
  }

  /// Le téléphone appelle, le PC répond : plus besoin de connaître son adresse IP.
  Future<void> _search({bool auto = false}) async {
    if (_searching) return;
    setState(() => _searching = true);
    _link.reportProblem('Je cherche ton PC...');
    List<FoundPc> pcs;
    try {
      pcs = await discoverPcs();
    } catch (_) {
      pcs = const [];
    }
    if (!mounted) return;
    setState(() => _searching = false);

    final name = _pairing?.pcName;
    final mine = name == null ? pcs : pcs.where((p) => p.name == name).toList();
    if (mine.isEmpty) {
      _link.reportProblem('PC introuvable');
      _snack(pcs.isEmpty
          ? 'Aucun PC trouvé. Vérifie que PandaPointer tourne sur le PC, que le PC '
              'est sur le même réseau (ou sur ton partage de connexion) et que le '
              'pare-feu Windows autorise le port 4210 (voir le README).'
          : 'Un PC a répondu (${pcs.first.name}) mais ce n\'est pas celui que tu as appairé ($name).');
      return;
    }
    await _connectTo(mine.first.address.address);
  }

  Future<void> _connectTo(String ip) async {
    _ip.text = ip;
    await _link.connect(ip);
  }

  // ------------------------------------------------------------------ interface

  Color get _statusColor => _link.online
      ? Pp.good
      : (_link.connected || _searching ? Pp.warn : Pp.muted);

  Widget _header() {
    return ListenableBuilder(
      listenable: _link,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
        child: Row(
          children: [
            Text('PANDAPOINTER',
                style: ppLabel(color: Pp.text, size: 18)
                    .copyWith(letterSpacing: 3)),
            const Spacer(),
            if (_pairing != null)
              Semantics(
                button: true,
                label: 'Connexion : ${_link.status}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _openSettings,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    child: Row(children: [
                      StatusDot(color: _statusColor),
                      const SizedBox(width: 8),
                      Text(
                        _link.online
                            ? _pairing!.pcName
                            : (_link.connected || _searching
                                ? 'CONNEXION...'
                                : 'HORS LIGNE'),
                        style: ppMono(color: _statusColor),
                      ),
                      const SizedBox(width: 10),
                      const PpIcon('gears', size: 20, color: Pp.muted),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabPills() {
    const labels = ['GYRO', 'PAVÉ', 'SLIDES'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: AnimatedBuilder(
        animation: _tabs.animation!,
        builder: (context, _) {
          final current = _tabs.animation!.value.round();
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: current == i,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tabs.animateTo(i),
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: current == i
                                ? Pp.accent
                                : const Color(0xFF241C17),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(labels[i],
                              style: ppLabel(
                                      color: current == i ? Pp.bg : Pp.muted,
                                      size: 13)
                                  .copyWith(letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _openSettings() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: ListenableBuilder(
          listenable: _link,
          builder: (context, _) => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  StatusDot(color: _statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_pairing?.pcName ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 20)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(_link.status, style: ppMono(color: Pp.muted, size: 13)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                    child: RaisedKey(
                      label: _link.connected ? 'DÉCONNECTER' : 'CONNECTER',
                      height: 56,
                      accent: !_link.connected,
                      onTap: () {
                        if (_link.connected) {
                          _link.disconnect();
                        } else {
                          _autoConnect();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RaisedKey(
                      label: _searching ? 'RECHERCHE...' : 'CHERCHER',
                      icon: 'search',
                      height: 56,
                      onTap: _searching ? null : _search,
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                TextField(
                  controller: _ip,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Adresse IP du PC (si besoin)',
                    hintText: '192.168.1.20',
                    isDense: true,
                  ),
                  onSubmitted: _connectTo,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _connectTo(_ip.text),
                  child: const Text('CONNECTER À CETTE ADRESSE'),
                ),
                const SizedBox(height: 22),
                TextButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Pp.panel,
                        title: const Text('Oublier ce PC ?'),
                        content: const Text(
                            'Tu devras refaire l\'appairage avec le QR code pour le piloter à nouveau.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('ANNULER')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('OUBLIER')),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await _forget();
                      nav.pop();
                    }
                  },
                  icon: const PpIcon('trash', size: 20, color: Pp.accentSoft),
                  label: const Text('OUBLIER CE PC (RÉAPPAIRER)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (!_loaded) {
      body = const Center(child: CircularProgressIndicator(color: Pp.accent));
    } else if (_pairing == null) {
      body = PairingPage(onPaired: _onPaired);
    } else {
      body = Column(children: [
        _tabPills(),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            // Le glissement horizontal entre onglets entrerait en conflit avec le pavé.
            physics: const NeverScrollableScrollPhysics(),
            children: [
              GyroPage(link: _link, pointer: _pointer),
              TouchpadPage(link: _link),
              SlidesPage(link: _link, pointer: _pointer),
            ],
          ),
        ),
      ]);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [_header(), Expanded(child: body)]),
        ),
      ),
    );
  }
}

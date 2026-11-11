// PandaPointer, côté téléphone.
//
// Étape 2 : trois onglets (Gyro, Pavé tactile, Slides) qui partagent la même
// connexion au PC. La connexion (adresse IP, bouton Connecter) reste en haut,
// visible quel que soit l'onglet.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'discovery.dart';
import 'gyro_page.dart';
import 'gyro_pointer.dart';
import 'link.dart';
import 'slides_page.dart';
import 'touchpad_page.dart';

void main() => runApp(const PandaPointerApp());

class PandaPointerApp extends StatelessWidget {
  const PandaPointerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PandaPointer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD2552B)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final Link _link = Link();
  late final GyroPointer _pointer = GyroPointer(_link);
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final TextEditingController _ip = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Le mode "toujours actif" du gyro n'a de sens que sur l'onglet Slides.
    _tabs.addListener(() => _pointer.slidesMode = _tabs.index == 2);
    _loadLastIp();
  }

  static const _ipKey = 'last_ip';
  bool _searching = false;

  /// Retrouve la dernière adresse utilisée (pratique sur le Wi-Fi de la maison).
  Future<void> _loadLastIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString(_ipKey);
      if (ip != null && _ip.text.isEmpty && mounted) _ip.text = ip;
    } catch (_) {
      // Pas grave : on tapera l'adresse.
    }
  }

  Future<void> _connectTo(String ip) async {
    _ip.text = ip;
    _link.connect(ip);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_ipKey, ip.trim());
    } catch (_) {}
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 6)));
  }

  /// Le téléphone appelle, le PC répond : plus besoin de connaître son adresse IP.
  Future<void> _search() async {
    setState(() => _searching = true);
    List<FoundPc> pcs;
    try {
      pcs = await discoverPcs();
    } catch (_) {
      pcs = const [];
    }
    if (!mounted) return;
    setState(() => _searching = false);

    if (pcs.isEmpty) {
      _snack('Aucun PC trouvé. Vérifie que le programme tourne sur le PC '
          '(cargo run), que le PC est sur le même réseau (ou connecté à ton '
          'partage de connexion) et que le pare-feu Windows autorise le port 4210 '
          '(voir le README).');
      return;
    }
    FoundPc? chosen = pcs.first;
    if (pcs.length > 1) {
      chosen = await showDialog<FoundPc>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Quel PC ?'),
          children: [
            for (final pc in pcs)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, pc),
                child: Text('${pc.name}  (${pc.address.address})'),
              ),
          ],
        ),
      );
    }
    if (chosen == null) return;
    await _connectTo(chosen.address.address);
    _snack('PC trouvé : ${chosen.name}');
  }

  @override
  void dispose() {
    _tabs.dispose();
    _pointer.dispose();
    _link.dispose();
    _ip.dispose();
    super.dispose();
  }

  Widget _connectionBar() {
    return ListenableBuilder(
      listenable: _link,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ip,
                    enabled: !_link.connected,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Adresse IP du PC',
                      hintText: '192.168.1.20',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _link.connected
                      ? _link.disconnect
                      : () => _connectTo(_ip.text),
                  child: Text(_link.connected ? 'Déconnecter' : 'Connecter'),
                ),
              ]),
              if (!_link.connected)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.search),
                    label:
                        Text(_searching ? 'Recherche...' : 'Chercher mon PC'),
                  ),
                ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('${_link.status}  ·  ${_link.sent} paquets envoyés',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PandaPointer'),
        bottom: TabBar(controller: _tabs, tabs: const [
          Tab(icon: Icon(Icons.screen_rotation), text: 'Gyro'),
          Tab(icon: Icon(Icons.touch_app), text: 'Pavé'),
          Tab(icon: Icon(Icons.slideshow), text: 'Slides'),
        ]),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _connectionBar(),
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
          ],
        ),
      ),
    );
  }
}

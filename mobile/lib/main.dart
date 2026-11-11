// PandaPointer, côté téléphone.
//
// Étape 2 : trois onglets (Gyro, Pavé tactile, Slides) qui partagent la même
// connexion au PC. La connexion (adresse IP, bouton Connecter) reste en haut,
// visible quel que soit l'onglet.

import 'package:flutter/material.dart';

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
                      : () => _link.connect(_ip.text),
                  child: Text(_link.connected ? 'Déconnecter' : 'Connecter'),
                ),
              ]),
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

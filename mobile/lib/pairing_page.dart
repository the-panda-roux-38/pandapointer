// Premier lancement : appairer le téléphone avec le PC (une seule fois).

import 'package:flutter/material.dart';

import 'scan_page.dart';
import 'secure.dart';
import 'theme.dart';
import 'widgets.dart';

class PairingPage extends StatefulWidget {
  const PairingPage({super.key, required this.onPaired});

  /// Appelé quand un QR code (ou un lien) valide a été lu.
  final void Function(Pairing pairing) onPaired;

  @override
  State<PairingPage> createState() => _PairingPageState();
}

class _PairingPageState extends State<PairingPage> {
  final TextEditingController _link = TextEditingController();
  bool _showPaste = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final pairing = await Navigator.of(context)
        .push<Pairing>(MaterialPageRoute(builder: (_) => const ScanPage()));
    if (pairing != null) widget.onPaired(pairing);
  }

  void _usePasted() {
    final pairing = Pairing.fromUrl(_link.text);
    if (pairing == null) {
      setState(() => _error =
          'Ce lien ne ressemble pas à un lien PandaPointer (il commence par pandapointer://pair).');
      return;
    }
    widget.onPaired(pairing);
  }

  Widget _step(String n, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Pp.keyTop,
                border: Border.all(color: Pp.edge, width: 2),
              ),
              child: Text(n, style: ppMono(size: 15)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(body,
                      style: const TextStyle(
                          color: Pp.muted, fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      children: [
        const Align(
            alignment: Alignment.centerLeft, child: PandaMark(width: 72)),
        const SizedBox(height: 14),
        const Text('Appairer ton PC',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 28)),
        const SizedBox(height: 6),
        const Text(
          'À faire une seule fois. Ensuite, le téléphone se reconnecte tout seul, '
          'et personne d\'autre sur le Wi-Fi ne peut piloter ton PC.',
          style: TextStyle(color: Pp.muted, height: 1.4),
        ),
        const SizedBox(height: 26),
        _step('1', 'Lance PandaPointer sur le PC',
            'Une petite icône de panda apparaît près de l\'horloge.'),
        _step('2', 'Clic droit sur l\'icône',
            'Choisis « Appairer un téléphone » : un QR code s\'affiche.'),
        _step('3', 'Scanne-le ici',
            'Le téléphone retrouve ensuite ton PC tout seul.'),
        const SizedBox(height: 8),
        RaisedKey(
          label: 'SCANNER LE QR CODE',
          icon: 'qr_code',
          accent: true,
          height: 64,
          onTap: _scan,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => setState(() => _showPaste = !_showPaste),
            child: const Text('LA CAMÉRA NE MARCHE PAS ? COLLER LE LIEN'),
          ),
        ),
        if (_showPaste) ...[
          const SizedBox(height: 6),
          TextField(
            controller: _link,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Lien d\'appairage',
              hintText: 'pandapointer://pair?...',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _usePasted, child: const Text('APPAIRER')),
        ],
      ],
    );
  }
}

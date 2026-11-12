// Écran du scanner de QR code : on vise le QR code affiché par le programme du PC.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'secure.dart';
import 'theme.dart';
import 'widgets.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  String? _wrongCode;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final text = b.rawValue;
      if (text == null) continue;
      final pairing = Pairing.fromUrl(text);
      if (pairing != null) {
        _done = true;
        Navigator.of(context).pop(pairing);
        return;
      }
      setState(
          () => _wrongCode = "Ce QR code n'est pas celui de PandaPointer.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Pp.bg,
      appBar: AppBar(
        backgroundColor: Pp.bg,
        foregroundColor: Pp.text,
        title: Text('SCANNER LE QR CODE',
            style: ppLabel(color: Pp.text, size: 14)),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PpIcon('camera', size: 40, color: Pp.muted),
                    SizedBox(height: 14),
                    Text(
                      "La caméra n'est pas disponible. Autorise la caméra pour PandaPointer dans les réglages du téléphone, ou reviens en arrière et colle le lien à la place.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Pp.muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Cadre de visée
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Pp.accent, width: 4),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Pp.bg.withAlpha(235),
                border: Border.all(color: Pp.edge, width: 2),
              ),
              child: Text(
                _wrongCode ??
                    'Sur le PC : icône PandaPointer → « Appairer un téléphone ». Vise le QR code qui s\'affiche.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _wrongCode == null ? Pp.text : Pp.warn, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

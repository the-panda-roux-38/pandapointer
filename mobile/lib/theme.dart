// Le look de PandaPointer : une télécommande sombre, chaude, avec du relief.
//
// Idée : l'appli doit ressembler à un objet qu'on tient en main (boutons gravés, molette
// concave, jauges à segments) plutôt qu'à un formulaire. Tout le monde pioche ses couleurs ici,
// ce qui permet de tout changer d'un seul endroit.

import 'package:flutter/material.dart';

class Pp {
  static const bg = Color(0xFF17120F); // fond de la télécommande
  static const panel = Color(0xFF1E1713); // panneaux de réglage
  static const keyTop = Color(0xFF352A23); // haut d'une touche
  static const keyBottom = Color(0xFF2A211B); // bas d'une touche
  static const edge = Color(0xFF4B3B30); // liseré lumineux
  static const depth = Color(0xFF0B0807); // ombre sous les touches
  static const segOff = Color(0xFF33271F); // segment éteint
  static const text = Color(0xFFF1E6DA);
  static const muted = Color(0xFFA58F7E);
  static const accent = Color(0xFFE9622F); // orange panda roux
  static const accentSoft = Color(0xFFF08A5D);
  static const good = Color(0xFF6BE08A);
  static const warn = Color(0xFFF2B14B);

  static const display = 'SpaceGrotesk';
  static const mono = 'JetBrainsMono';
}

TextStyle ppLabel({Color color = Pp.muted, double size = 12}) => TextStyle(
      fontFamily: Pp.display,
      fontWeight: FontWeight.w700,
      fontSize: size,
      letterSpacing: 2,
      color: color,
    );

TextStyle ppMono({Color color = Pp.accent, double size = 12}) => TextStyle(
      fontFamily: Pp.mono,
      fontWeight: FontWeight.w500,
      fontSize: size,
      color: color,
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Pp.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Pp.accent,
    onPrimary: Pp.bg,
    surface: Pp.bg,
    onSurface: Pp.text,
    secondaryContainer: Pp.keyTop,
    onSecondaryContainer: Pp.text,
    primaryContainer: Pp.keyBottom,
    onPrimaryContainer: Pp.text,
    surfaceContainerHighest: Pp.panel,
    outline: Pp.edge,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pp.bg,
    fontFamily: Pp.display,
    textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(
        fontFamily: Pp.display, bodyColor: Pp.text, displayColor: Pp.text),
    dividerColor: Pp.edge,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Pp.bg : Pp.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Pp.accent : Pp.segOff),
      trackOutlineColor: WidgetStateProperty.all(Pp.edge),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStateProperty.all(const BorderSide(color: Pp.edge)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Pp.accent : Pp.panel),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Pp.bg : Pp.text),
        textStyle: WidgetStateProperty.all(const TextStyle(
            fontFamily: Pp.display, fontWeight: FontWeight.w700, letterSpacing: 1)),
        shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pp.accent,
        foregroundColor: Pp.bg,
        textStyle: const TextStyle(
            fontFamily: Pp.display,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Pp.text,
        side: const BorderSide(color: Pp.edge),
        textStyle: const TextStyle(
            fontFamily: Pp.display,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(48, 48),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Pp.accentSoft,
        textStyle:
            const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Pp.panel,
      labelStyle: const TextStyle(color: Pp.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Pp.edge),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Pp.edge),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Pp.accent, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Pp.panel,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Pp.keyTop,
      contentTextStyle: const TextStyle(color: Pp.text, fontFamily: Pp.display),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

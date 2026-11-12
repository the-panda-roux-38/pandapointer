// L'identité de PandaPointer : le même panda roux et le même crépuscule que mcpanda.fr et Coche.
//
// Règles du style (à respecter pour tout nouvel écran) :
//  - aucun arrondi : tout est rectangle, comme les cubes (voxels) du logo MC ;
//  - aucun dégradé, aucune lueur, aucune ombre floue : des aplats ;
//  - le relief, c'est une « face » de cube : un bloc de couleur plus sombre sous la touche ;
//  - le roux est réservé aux actions et à ce qui est actif ; le vert bambou dit « ça marche ».
// Tout le monde pioche ses couleurs ici, ce qui permet de tout changer d'un seul endroit.

import 'package:flutter/material.dart';

class Pp {
  static const bg =
      Color(0xFF1B1410); // brun crépuscule (le fond de mcpanda.fr)
  static const panel = Color(0xFF241A14); // blocs de réglage
  static const keyTop = Color(0xFF3A2C22); // face d'une touche
  static const keyBottom = Color(0xFF2E221A); // zone enfoncée
  static const edge = Color(0xFF4D3A2D); // contours
  static const depth = Color(0xFF0F0A07); // flanc d'une touche
  static const segOff = Color(0xFF35271E); // segment éteint
  static const text = Color(0xFFF8F1E6); // crème du panda
  static const muted = Color(0xFFB3A08C);
  static const accent = Color(0xFFC4532A); // roux brûlé du panda
  static const accentDeep = Color(0xFF8C3417); // flanc d'une touche rousse
  static const accentSoft =
      Color(0xFFE58A62); // roux clair, pour le texte sur fond sombre
  static const good = Color(0xFF6EA64F); // vert bambou
  static const warn = Color(0xFFD9A441);

  static const display = 'Bricolage';
}

TextStyle ppLabel({Color color = Pp.muted, double size = 12}) => TextStyle(
      fontFamily: Pp.display,
      fontWeight: FontWeight.w800,
      fontSize: size,
      letterSpacing: 1.6,
      color: color,
    );

/// Valeurs et chiffres (même police, en gras, pour rester lisibles).
TextStyle ppMono({Color color = Pp.accentSoft, double size = 12}) => TextStyle(
      fontFamily: Pp.display,
      fontWeight: FontWeight.w700,
      fontSize: size,
      letterSpacing: 0.4,
      color: color,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

const _square = RoundedRectangleBorder();

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Pp.accent,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Pp.accent,
    onPrimary: Pp.text,
    surface: Pp.bg,
    onSurface: Pp.text,
    secondaryContainer: Pp.accent,
    onSecondaryContainer: Pp.text,
    primaryContainer: Pp.keyBottom,
    onPrimaryContainer: Pp.text,
    surfaceContainerHighest: Pp.panel,
    outline: Pp.edge,
  );
  const labelStyle = TextStyle(
      fontFamily: Pp.display,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
      fontSize: 13);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Pp.bg,
    fontFamily: Pp.display,
    splashFactory: NoSplash.splashFactory,
    textTheme: ThemeData(brightness: Brightness.dark).textTheme.apply(
        fontFamily: Pp.display, bodyColor: Pp.text, displayColor: Pp.text),
    dividerColor: Pp.edge,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Pp.accent),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side:
            WidgetStateProperty.all(const BorderSide(color: Pp.edge, width: 2)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Pp.accent : Pp.panel),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Pp.text : Pp.muted),
        textStyle: WidgetStateProperty.all(labelStyle),
        shape: WidgetStateProperty.all(_square),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Pp.accent,
        foregroundColor: Pp.text,
        textStyle: labelStyle,
        shape: _square,
        minimumSize: const Size(48, 52),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Pp.text,
        side: const BorderSide(color: Pp.edge, width: 2),
        textStyle: labelStyle,
        shape: _square,
        minimumSize: const Size(48, 52),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Pp.accentSoft,
        textStyle: labelStyle,
        shape: _square,
        minimumSize: const Size(48, 48),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Pp.panel,
      labelStyle: TextStyle(color: Pp.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Pp.edge, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Pp.edge, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Pp.accent, width: 2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Pp.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: BorderSide(color: Pp.edge, width: 2)),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Pp.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(side: BorderSide(color: Pp.edge, width: 2)),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Pp.keyTop,
      contentTextStyle: TextStyle(
          color: Pp.text, fontFamily: Pp.display, fontSize: 14, height: 1.35),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(side: BorderSide(color: Pp.edge, width: 2)),
    ),
  );
}

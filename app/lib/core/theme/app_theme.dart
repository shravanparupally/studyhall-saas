import 'package:flutter/material.dart';

/// Light/dark [ThemeData] shared by every screen.
///
/// The seed color below is an interim value, not a brand decision — per
/// docs/09_UI_UX_Guidelines.md §9.6, visual identity (logo, palette,
/// typography) is deliberately not finalized yet, pending
/// product-market validation. This is the "clearly placeholder-marked
/// palette" that section calls for, not a final design choice.
///
/// Text scaling is intentionally left at the system default everywhere
/// (§9.3 — never lock text size) and color contrast must stay at WCAG AA
/// or above once real content/colors land here.
abstract final class AppTheme {
  static const _seedColor = Color(0xFF2E5AAC);

  /// The default (light) theme.
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seedColor),
  );

  /// The dark-mode theme.
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    ),
  );
}

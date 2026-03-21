import 'package:flutter/material.dart';

/// Added: central theme helper so dark-mode readability stays consistent across EduLense pages.
class AppThemeHelper {
  /// Added: reusable check for whether the current theme is dark.
  static bool isDark(BuildContext context) {
    // Added: inspect the active theme brightness so all pages can adapt colors consistently.
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Added: returns a readable title color for cards, tables, and panels.
  static Color titleColor(BuildContext context) {
    // Added: prefer high-contrast onSurface text so dark mode remains legible.
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Added: returns a readable body color for descriptive text.
  static Color bodyColor(BuildContext context) {
    // Added: slightly soften body text while keeping enough contrast for dark mode.
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.88);
  }

  /// Added: returns a muted readable caption color for helper text.
  static Color mutedColor(BuildContext context) {
    // Added: use a readable variant rather than hardcoded grey values that disappear in dark mode.
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.70);
  }

  /// Added: returns a surface color for content cards that works in both light and dark mode.
  static Color cardColor(BuildContext context) {
    // Added: use the Material color scheme instead of hardcoded white cards.
    return Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.60);
  }

  /// Added: returns a border color that remains visible in dark mode.
  static Color borderColor(BuildContext context) {
    // Added: re-use the outline color with a softer opacity for subtle but visible borders.
    return Theme.of(context).colorScheme.outline.withOpacity(0.35);
  }

  /// Added: returns a tinted highlight background for badges and banners.
  static Color tint(BuildContext context) {
    // Added: lightly tint containers with the selected theme color.
    return Theme.of(context).colorScheme.primary.withOpacity(0.10);
  }

  /// Added: builds a card decoration with theme-aware colors for pages that previously hardcoded white.
  static BoxDecoration panelDecoration(BuildContext context) {
    // Added: return a consistent decoration for navigation cards and section panels.
    return BoxDecoration(
      color: cardColor(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: borderColor(context), width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark(context) ? 0.18 : 0.05),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

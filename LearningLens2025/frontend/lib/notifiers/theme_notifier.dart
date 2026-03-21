import 'package:flutter/material.dart';
import 'package:learninglens_app/services/local_storage_service.dart';

/// Added: model that supports both single-color and multi-color EduLense theme presets.
class EduLenseThemeOption {
  /// Added: stable key persisted in local storage.
  final String id;

  /// Added: human-readable label shown in the settings page.
  final String name;

  /// Added: primary seed color for the Material color scheme.
  final Color primaryColor;

  /// Added: optional secondary color used for gradient previews and richer multicolor themes.
  final Color secondaryColor;

  const EduLenseThemeOption({
    required this.id,
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
  });
}

class ThemeNotifier extends ChangeNotifier {
  // Added: keep a richer default purple that matches the EduLense UI screenshots more closely.
  Color _primaryColor = const Color(0xFF7C4DFF);

  // Added: keep a secondary accent so EduLense can support richer multicolor themes.
  Color _secondaryColor = const Color(0xFFB388FF);

  // Added: track whether the user wants the interface rendered in dark mode.
  bool _isDarkMode = false;

  // Added: store the selected preset id so the settings page can highlight multicolor themes.
  String _selectedThemeId = 'classic-purple';

  // Added: expose a curated palette that the settings page can reuse.
  static const List<Color> availableThemeColors = [
    // Added: the original energetic purple remains available.
    Color(0xFF7C4DFF),
    // Added: vivid electric blue for a clean modern dashboard look.
    Color(0xFF2979FF),
    // Added: bright teal for a fresh classroom-friendly interface.
    Color(0xFF00B8D4),
    // Added: sunset coral for a warm vibrant option.
    Color(0xFFFF7043),
    // Added: magenta pink for a playful high-energy theme.
    Color(0xFFE91E63),
    // Added: emerald green for a bold productivity-oriented theme.
    Color(0xFF00C853),
    // Added: golden amber for a bright premium-looking accent.
    Color(0xFFFFB300),
    // Added: indigo navy for a more professional desktop feel.
    Color(0xFF3949AB),
    // Added: grape violet for another vivid but softer option.
    Color(0xFF8E24AA),
  ];

  // Added: richer named presets including the requested multicolor themes.
  static const List<EduLenseThemeOption> availableThemeOptions = [
    EduLenseThemeOption(
      id: 'classic-purple',
      name: 'Classic Purple',
      primaryColor: Color(0xFF7C4DFF),
      secondaryColor: Color(0xFFB388FF),
    ),
    EduLenseThemeOption(
      id: 'electric-blue',
      name: 'Electric Blue',
      primaryColor: Color(0xFF2979FF),
      secondaryColor: Color(0xFF00C2FF),
    ),
    EduLenseThemeOption(
      id: 'fresh-teal',
      name: 'Fresh Teal',
      primaryColor: Color(0xFF00B8D4),
      secondaryColor: Color(0xFF64FFDA),
    ),
    EduLenseThemeOption(
      id: 'sunset-coral',
      name: 'Sunset Coral',
      primaryColor: Color(0xFFFF7043),
      secondaryColor: Color(0xFFFFB199),
    ),
    EduLenseThemeOption(
      id: 'baby-blue-pink',
      name: 'Baby Blue + Pink',
      primaryColor: Color(0xFF7EC8FF),
      secondaryColor: Color(0xFFFF9ECF),
    ),
    EduLenseThemeOption(
      id: 'purple-orange-fusion',
      name: 'Purple + Orange',
      primaryColor: Color(0xFF8E24AA),
      secondaryColor: Color(0xFFFF9800),
    ),
  ];

  // Added: initialize the persisted color and theme mode when the notifier is created.
  ThemeNotifier() {
    // Added: restore the last saved primary color so the theme stays consistent after restart.
    _primaryColor = _colorFromHex(LocalStorageService.getPrimaryColor());
    // Added: restore the last saved secondary color used by multicolor themes.
    _secondaryColor = _colorFromHex(LocalStorageService.getSecondaryColor());
    // Added: restore the selected theme preset id for the settings preview state.
    _selectedThemeId = LocalStorageService.getThemePresetId();
    // Added: restore the last saved light or dark preference.
    _isDarkMode = LocalStorageService.getTheme().toLowerCase() == 'dark';
  }

  Color get primaryColor => _primaryColor;

  // Added: expose the secondary accent for gradient previews and richer components.
  Color get secondaryColor => _secondaryColor;

  // Added: expose the selected preset id for the settings page.
  String get selectedThemeId => _selectedThemeId;

  // Added: expose the current theme mode to MaterialApp.
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Added: expose the boolean for settings page switches and chips.
  bool get isDarkMode => _isDarkMode;

  void updateTheme(Color color) {
    // Added: update the in-memory primary color used across the app.
    _primaryColor = color;
    // Added: derive a close secondary accent so custom colors still feel multi-dimensional.
    _secondaryColor = Color.lerp(color, Colors.white, 0.35) ?? color;
    // Added: clear the named preset selection when the user manually picks a custom color.
    _selectedThemeId = 'custom';
    // Added: persist the new color so Flutter web and desktop keep the same theme after restart.
    LocalStorageService.savePrimaryColor(_colorToHex(color));
    // Added: persist the derived secondary accent for richer gradients.
    LocalStorageService.saveSecondaryColor(_colorToHex(_secondaryColor));
    // Added: persist the custom preset marker.
    LocalStorageService.saveThemePresetId(_selectedThemeId);
    notifyListeners();
  }

  // Added: apply a named single-color or multi-color EduLense preset.
  void updateThemeOption(EduLenseThemeOption option) {
    // Added: store the selected preset colors in memory.
    _primaryColor = option.primaryColor;
    _secondaryColor = option.secondaryColor;
    _selectedThemeId = option.id;
    // Added: persist the chosen preset colors and id.
    LocalStorageService.savePrimaryColor(_colorToHex(option.primaryColor));
    LocalStorageService.saveSecondaryColor(_colorToHex(option.secondaryColor));
    LocalStorageService.saveThemePresetId(option.id);
    notifyListeners();
  }

  // Added: allow the settings page to switch between light and dark mode.
  void updateThemeMode(bool isDarkMode) {
    // Added: update the in-memory theme mode.
    _isDarkMode = isDarkMode;
    // Added: persist the theme mode so it survives page refreshes.
    LocalStorageService.saveTheme(isDarkMode ? 'dark' : 'light');
    notifyListeners();
  }

  // Added: convert a Flutter color into a storage-friendly hex string.
  String _colorToHex(Color color) {
    // Added: include alpha so the stored value round-trips safely.
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Added: parse a stored hex color while safely falling back to the EduLense purple.
  Color _colorFromHex(String hexValue) {
    // Added: normalize the value to avoid issues with # or missing alpha.
    final normalizedHex = hexValue.replaceAll('#', '');

    // Added: accept both RRGGBB and AARRGGBB formats from storage.
    if (normalizedHex.length == 6) {
      return Color(int.parse('FF$normalizedHex', radix: 16));
    }

    // Added: prefer the stored 8-digit value when it already includes alpha.
    if (normalizedHex.length == 8) {
      return Color(int.parse(normalizedHex, radix: 16));
    }

    // Added: fall back gracefully if storage contains an unexpected value.
    return const Color(0xFF7C4DFF);
  }
}

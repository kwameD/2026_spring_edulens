import 'package:flutter/material.dart';
import 'package:learninglens_app/theme/app_theme_helper.dart';

class NavigationCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onPressed;

  const NavigationCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    // Added: capture the active color scheme so icons and hover states follow the selected theme.
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      // Added: use a theme-aware surface color so cards stay readable in dark mode.
      color: AppThemeHelper.cardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // Added: use a theme-aware border instead of a hardcoded light grey line.
          color: AppThemeHelper.borderColor(context),
          width: 1.5,
        ),
      ),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Added: tint the icon with the selected theme color for a more vibrant dashboard.
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppThemeHelper.titleColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: AppThemeHelper.bodyColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

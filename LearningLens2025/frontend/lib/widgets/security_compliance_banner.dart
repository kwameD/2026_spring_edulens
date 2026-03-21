import 'package:flutter/material.dart';
import 'package:learninglens_app/theme/app_theme_helper.dart';

/// Added: shared security banner that reinforces university-contained processing requirements.
class SecurityComplianceBanner extends StatelessWidget {
  /// Added: allow pages to tailor the short label while reusing the same banner layout.
  final String label;

  const SecurityComplianceBanner({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    // Added: grab the active color scheme once for consistent security-state styling.
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppThemeHelper.titleColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'EduLense is configured to keep prompts, outputs, and sensitive classroom data inside university-controlled infrastructure. No external LLM provider is required for this workflow.',
                  style: TextStyle(
                    color: AppThemeHelper.bodyColor(context),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:learninglens_app/theme/app_theme_helper.dart';

/// Added: simple image asset model used by the visual-materials panel.
class VisualMaterialAsset {
  /// Added: user-visible file name for the selected instructional image.
  final String name;

  /// Added: optional in-memory bytes so web builds can preview uploaded images instantly.
  final Uint8List? bytes;

  /// Added: short instructional role for how the image should be used in the generated artifact.
  final String purpose;

  const VisualMaterialAsset({
    required this.name,
    required this.bytes,
    required this.purpose,
  });
}

/// Added: reusable panel for image integration across assignments, games, and teacher artifacts.
class VisualMaterialsPanel extends StatelessWidget {
  /// Added: current image assets selected by the educator.
  final List<VisualMaterialAsset> assets;

  /// Added: callback that lets the host page update its selected instructional images.
  final ValueChanged<List<VisualMaterialAsset>> onAssetsChanged;

  const VisualMaterialsPanel({
    super.key,
    required this.assets,
    required this.onAssetsChanged,
  });

  /// Added: picks one or more visual materials and returns updated assets to the host page.
  Future<void> _pickAssets(BuildContext context) async {
    // Added: let educators attach common instructional image formats directly from the browser or desktop.
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      withData: true,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
    );

    // Added: stop if the educator canceled the picker.
    if (result == null) {
      return;
    }

    // Added: build a new list so the host page can update state in one place.
    final updatedAssets = <VisualMaterialAsset>[...assets];

    // Added: convert each selected file into a visual-material entry with a classroom-oriented default purpose.
    for (final file in result.files) {
      updatedAssets.add(
        VisualMaterialAsset(
          name: file.name,
          bytes: file.bytes,
          purpose: 'Annotated example',
        ),
      );
    }

    // Added: notify the host page that the visual-material list changed.
    onAssetsChanged(updatedAssets);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppThemeHelper.panelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visual Materials / Image Integration',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppThemeHelper.titleColor(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Treat images as first-class instructional assets. Add diagrams, annotated examples, roleplay visuals, or scenario cards that can be embedded into teacher-facing outputs and classroom exports.',
            style: TextStyle(
              color: AppThemeHelper.bodyColor(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => _pickAssets(context),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Add Instructional Images'),
              ),
              Chip(
                avatar: const Icon(Icons.file_download_done_outlined, size: 18),
                label: const Text('Visual + text export ready'),
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.70),
              ),
              Chip(
                avatar: const Icon(Icons.security_outlined, size: 18),
                label: const Text('University-contained processing'),
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer.withOpacity(0.70),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (assets.isEmpty)
            Text(
              'No visual materials added yet.',
              style: TextStyle(
                color: AppThemeHelper.mutedColor(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          if (assets.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: assets.asMap().entries.map((entry) {
                // Added: keep both the asset and index so we can remove individual images.
                final index = entry.key;
                final asset = entry.value;

                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surface
                        .withOpacity(AppThemeHelper.isDark(context) ? 0.85 : 1.0),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppThemeHelper.borderColor(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: asset.bytes != null
                            ? Image.memory(
                                asset.bytes!,
                                height: 110,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 110,
                                width: double.infinity,
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(Icons.image_outlined, size: 40),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        asset.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppThemeHelper.titleColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        asset.purpose,
                        style: TextStyle(
                          color: AppThemeHelper.mutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            // Added: create a new list without the tapped image and report it back to the host.
                            final updatedAssets = <VisualMaterialAsset>[...assets]
                              ..removeAt(index);
                            onAssetsChanged(updatedAssets);
                          },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Tip: Flutter web previews uploaded instructional images directly in Chrome so teachers can verify classroom visuals before export.',
                style: TextStyle(
                  color: AppThemeHelper.mutedColor(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Product imagery with a calm, category-specific fallback for offline records.
class ProductArtwork extends StatelessWidget {
  final String imagePath;
  final String category;
  final BoxFit fit;

  const ProductArtwork({
    super.key,
    required this.imagePath,
    required this.category,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      );
    }

    if (imagePath.isNotEmpty) {
      try {
        final imageFile = File(imagePath);
        if (imageFile.existsSync()) {
          return Image.file(
            imageFile,
            fit: fit,
            errorBuilder: (context, error, stackTrace) => _fallback(),
          );
        }
      } catch (_) {
        // Keep the catalog usable when a saved photo is unavailable.
      }
    }

    return _fallback();
  }

  Widget _fallback() {
    final icon = switch (category) {
      'Burung Kicau' => Icons.flutter_dash,
      'Pakan & Voer' => Icons.grain,
      'Sangkar' => Icons.grid_view_rounded,
      'Obat & Vitamin' => Icons.medication_outlined,
      _ => Icons.inventory_2_outlined,
    };

    return ColoredBox(
      color: AppColors.surfaceCardMuted,
      child: Center(child: Icon(icon, size: 32, color: AppColors.primaryGreen)),
    );
  }
}

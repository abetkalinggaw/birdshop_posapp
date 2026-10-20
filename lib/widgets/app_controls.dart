import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppBadgeTone { positive, warning, critical, neutral, info }

/// One vocabulary for operational states across catalog, receipts and sessions.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeTone tone;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.tone = AppBadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      AppBadgeTone.positive => (
        AppColors.badgeGreenBg,
        AppColors.badgeGreenText,
      ),
      AppBadgeTone.warning => (
        AppColors.badgeAmberBg,
        AppColors.badgeAmberText,
      ),
      AppBadgeTone.critical => (AppColors.badgeRedBg, AppColors.badgeRedText),
      AppBadgeTone.neutral => (
        AppColors.badgeNeutralBg,
        AppColors.badgeNeutralText,
      ),
      AppBadgeTone.info => (AppColors.badgeInfoBg, AppColors.badgeInfoText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category, period and sort filters share selected and focus treatments.
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : AppColors.textSecondary,
      ),
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }
}

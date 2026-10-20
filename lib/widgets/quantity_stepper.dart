import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class QuantityStepper extends StatelessWidget {
  final int value;
  final int minValue;
  final int? maxValue;
  final ValueChanged<int> onChanged;
  final bool compact;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.minValue = 0,
    this.maxValue,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const buttonSize = 48.0;
    final iconSize = compact ? 18.0 : 20.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.actionSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            size: buttonSize,
            iconSize: iconSize,
            enabled: value > minValue,
            onPressed: () {
              if (value > minValue) {
                onChanged(value - 1);
              }
            },
          ),
          Container(
            constraints: BoxConstraints(minWidth: compact ? 32 : 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            size: buttonSize,
            iconSize: iconSize,
            enabled: maxValue == null || value < maxValue!,
            onPressed: () {
              if (maxValue == null || value < maxValue!) {
                onChanged(value + 1);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final bool enabled;
  final VoidCallback onPressed;

  const _StepButton({
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          width: size,
          height: size,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? AppColors.primaryGreen : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

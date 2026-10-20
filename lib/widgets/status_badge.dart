import 'package:flutter/material.dart';

import '../models/product.dart';
import 'app_controls.dart';

class StatusBadge extends StatelessWidget {
  final StockStatus status;
  final String? customLabel;
  const StatusBadge({super.key, required this.status, this.customLabel});

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (status) {
      StockStatus.safe => (AppBadgeTone.positive, 'Stok aman'),
      StockStatus.low => (AppBadgeTone.warning, 'Menipis'),
      StockStatus.critical => (AppBadgeTone.critical, 'Stok kritis'),
      StockStatus.outOfStock => (AppBadgeTone.critical, 'Habis'),
    };
    return AppBadge(label: customLabel ?? label, tone: tone);
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static String format(num value) {
    return _formatter.format(value);
  }

  static TextStyle get tabularStyle =>
      const TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
}

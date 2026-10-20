import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';

void main() {
  group('Satoshi Typography & Theme Verification', () {
    test('AppTheme defaults to Satoshi font family', () {
      expect(AppTheme.fontFamily, 'Satoshi');
      final theme = AppTheme.lightTheme;
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Satoshi');
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Satoshi');
      expect(theme.textTheme.headlineLarge?.fontFamily, 'Satoshi');
      expect(theme.textTheme.titleMedium?.fontFamily, 'Satoshi');
      expect(theme.textTheme.labelLarge?.fontFamily, 'Satoshi');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'Satoshi');
    });

    test('Typography hierarchy has refined letterSpacing and font weights', () {
      final theme = AppTheme.lightTheme;
      final textTheme = theme.textTheme;

      // Display and Headline should have negative letterSpacing for crisp titles
      expect(textTheme.headlineLarge?.letterSpacing, lessThan(0));
      expect(textTheme.headlineMedium?.letterSpacing, lessThan(0));

      // Labels and captions have positive letterSpacing for readability at small sizes
      expect(textTheme.labelSmall?.letterSpacing, greaterThan(0));
      expect(textTheme.bodyMedium?.letterSpacing, greaterThanOrEqualTo(0));

      // Weights are properly distinguished
      expect(textTheme.headlineLarge?.fontWeight, FontWeight.w700);
      expect(textTheme.titleMedium?.fontWeight, FontWeight.w600);
      expect(textTheme.bodyLarge?.fontWeight, FontWeight.w400);
    });
  });
}

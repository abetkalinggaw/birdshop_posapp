import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';
import 'package:birdshop_posapp/widgets/product_manage_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets(
    'failed product save keeps input and sheet open; retry saves once',
    (tester) async {
      final store = MemoryAuthStore();
      final c = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => AddProductModal.show(context),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
        ),
      );
      final before = c.read(inventoryProvider).products.length;
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nama Produk / Jenis Avian'),
        'Produk Tetap Tersimpan',
      );
      store.failWrites = true;
      await tester.tap(find.text('Tambah ke Inventaris'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Tambahkan'));
      await tester.pumpAndSettle();
      expect(find.byType(AddProductModal), findsOneWidget);
      expect(find.text('Produk Tetap Tersimpan'), findsOneWidget);
      expect(c.read(inventoryProvider).products.length, before);
      expect(
        find.text(
          'Data gagal disimpan. Data sebelumnya tetap tersedia. Coba lagi.',
        ),
        findsOneWidget,
      );
      store.failWrites = false;
      await tester.tap(find.text('Tambah ke Inventaris'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ya, Tambahkan'));
      await tester.pumpAndSettle();
      expect(find.byType(AddProductModal), findsNothing);
      expect(c.read(inventoryProvider).products.length, before + 1);
    },
  );
}

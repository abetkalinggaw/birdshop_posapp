import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';
import 'package:birdshop_posapp/widgets/product_manage_modal.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets(
    'add sheet preserves defaults, editable SKU and creation with keyboard and larger text',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
      );
      addTearDown(container.dispose);
      final originalCount = container.read(inventoryProvider).products.length;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (_, child) => MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(1.3),
                viewInsets: EdgeInsets.only(bottom: 300),
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => AddProductModal.show(context),
                  child: const Text('Open add'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open add'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Hapus'), findsNothing);
      final add = find.text('Tambah ke Inventaris');
      expect(tester.getRect(add).bottom, lessThan(500));
      final stock = find.widgetWithText(TextField, 'Stok Masuk Awal');
      final price = find.widgetWithText(TextField, 'Harga Jual Satuan');
      final minimum = find.widgetWithText(TextField, 'Min. Kritis');
      final sku = find.widgetWithText(TextField, 'Kode SKU');
      expect(tester.widget<TextField>(stock).controller!.text, '10');
      expect(tester.widget<TextField>(price).controller!.text, '50000');
      expect(tester.widget<TextField>(minimum).controller!.text, '3');
      expect(
        tester.widget<TextField>(sku).controller!.text,
        startsWith('SKU-'),
      );
      expect(tester.widget<TextField>(sku).readOnly, isFalse);
      await tester.ensureVisible(stock);
      await tester.enterText(stock, '6');
      await tester.ensureVisible(find.text('+10'));
      await tester.tap(find.text('+10'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(stock).controller!.text, '16');
      await tester.ensureVisible(minimum);
      await tester.enterText(minimum, '4');
      final name = find.widgetWithText(TextField, 'Nama Produk / Jenis Avian');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Voer Baru');
      final category = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pakan & Voer').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(sku);
      await tester.enterText(sku, 'SKU-NEW-TEST');
      await tester.ensureVisible(price);
      await tester.enterText(price, '75000');
      final tags = find.widgetWithText(TextField, 'Tag / Varian');
      await tester.ensureVisible(tags);
      await tester.enterText(tags, '500g, Premium');
      await tester.ensureVisible(find.text('Ambil Foto'));
      expect(find.text('Pilih dari Galeri'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('Tambah Produk Baru?'), findsOneWidget);
      await tester.tap(find.text('Ya, Tambahkan'));
      await tester.pumpAndSettle();
      final products = container.read(inventoryProvider).products;
      expect(products.length, originalCount + 1);
      final created = products.first;
      expect(created.sku, 'SKU-NEW-TEST');
      expect(created.name, 'Voer Baru');
      expect(created.category, 'Pakan & Voer');
      expect(created.stock, 16);
      expect(created.minStock, 4);
      expect(created.price, 75000);
      expect(created.tags, ['500g', 'Premium']);
      expect(created.imageUrl, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

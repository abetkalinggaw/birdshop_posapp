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
    'edit sheet keeps actions reachable with keyboard and larger text, then saves all edited fields',
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
      final product = container.read(inventoryProvider).products.first;
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
                  onPressed: () =>
                      EditProductModal.show(context, product: product),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.text('Simpan Perubahan');
      final remove = find.text('Hapus');
      expect(tester.getRect(save).bottom, lessThan(500));
      expect(tester.getRect(remove).bottom, lessThan(500));
      final stock = find.widgetWithText(TextField, 'Stok tersedia');
      await tester.ensureVisible(stock);
      await tester.enterText(stock, '8');
      final shortcut = find.text('+5');
      await tester.ensureVisible(shortcut);
      await tester.tap(shortcut);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(stock).controller!.text, '13');
      final minimum = find.widgetWithText(TextField, 'Min. Kritis');
      await tester.ensureVisible(minimum);
      await tester.enterText(minimum, '4');
      final name = find.widgetWithText(TextField, 'Nama Produk / Jenis Avian');
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Murai Batu Updated');
      final price = find.widgetWithText(TextField, 'Harga Jual Satuan');
      await tester.ensureVisible(price);
      await tester.enterText(price, '2600000');
      final tags = find.widgetWithText(TextField, 'Tag / Varian');
      await tester.ensureVisible(tags);
      await tester.enterText(tags, 'Ring APBN, Updated');
      await tester.ensureVisible(find.text('Ambil Foto'));
      expect(find.text('Pilih dari Galeri'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Simpan Perubahan?'), findsOneWidget);
      await tester.tap(find.text('Ya, Simpan'));
      await tester.pumpAndSettle();
      final saved = container.read(inventoryProvider).products.first;
      expect(saved.sku, product.sku);
      expect(saved.name, 'Murai Batu Updated');
      expect(saved.stock, 13);
      expect(saved.minStock, 4);
      expect(saved.price, 2600000);
      expect(saved.tags, ['Ring APBN', 'Updated']);
      expect(saved.imageUrl, product.imageUrl);
      expect(tester.takeException(), isNull);
    },
  );
}

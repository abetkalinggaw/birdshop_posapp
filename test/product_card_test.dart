import 'package:birdshop_posapp/providers/session_provider.dart';

import 'auth_test_support.dart';

import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdshop_posapp/main.dart';
import 'package:birdshop_posapp/models/product.dart';
import 'package:birdshop_posapp/widgets/product_card.dart';
import 'package:birdshop_posapp/widgets/product_manage_modal.dart';
import 'package:birdshop_posapp/widgets/quantity_stepper.dart';

void main() {
  testWidgets(
    'ProductCard renders minimalist design without QuantityStepper (- +)',
    (WidgetTester tester) async {
      const testProduct = Product(
        sku: 'SKU-MB001',
        name: 'Murai Batu Medan',
        category: 'Burung Kicau',
        price: 2450000,
        stock: 3,
        minStock: 5,
        imageUrl: '',
        tags: ['Ring APBN', 'Gacor'],
      );

      bool openedModal = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProductCard(
              product: testProduct,
              onManagePressed: () {
                openedModal = true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify product name, SKU, price are displayed
      expect(find.text('Murai Batu Medan'), findsOneWidget);
      expect(find.textContaining('SKU-MB001'), findsOneWidget);
      expect(find.text('Rp 2.450.000'), findsOneWidget);

      // Verify stock badge is rendered as a clean pill
      expect(find.text('3 unit'), findsOneWidget);

      // Verify NO QuantityStepper (- +) is present on the card
      expect(find.byType(QuantityStepper), findsNothing);

      // Verify minimalist '+' button is present with tooltip 'Kelola Produk'
      final addIcon = find.byIcon(Icons.edit_outlined);
      expect(addIcon, findsOneWidget);

      // Tap '+' button and verify callback is triggered
      await tester.tap(addIcon);
      expect(openedModal, isTrue);
    },
  );

  testWidgets(
    'EditProductModal opens independently without tab switcher and confirms on save',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(SignedInOwner.new),
            shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
          ],
          child: ExShaBirdShopApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to Inventaris tab via top bar action
      await tester.tap(find.text('Produk'));
      await tester.pumpAndSettle();

      // Verify ProductCard is rendered
      expect(find.byType(ProductCard), findsWidgets);

      // Tap '+' button on the first product card
      final firstPlusBtn = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(firstPlusBtn);
      await tester.pumpAndSettle();

      // Verify independent EditProductModal opened
      expect(find.byType(EditProductModal), findsOneWidget);
      expect(find.text('Kelola & Ubah Produk'), findsOneWidget);
      expect(find.text('Jumlah Stok Fisik'), findsOneWidget);

      // Verify NO tab switcher present in edit modal
      expect(find.text('+ Tambah Baru'), findsNothing);
      expect(find.text('Ubah Produk Ini'), findsNothing);

      // Test quick stock modifier (+5)
      await tester.tap(find.text('+5'));
      await tester.pumpAndSettle();

      // Tap 'Simpan Perubahan'
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      // Verify confirmation popup dialog appears
      expect(find.text('Simpan Perubahan?'), findsOneWidget);
      expect(find.text('Ya, Simpan'), findsOneWidget);

      // Confirm save in dialog
      await tester.tap(find.text('Ya, Simpan'));
      await tester.pumpAndSettle();

      // Modal should close and show SnackBar
      expect(find.byType(EditProductModal), findsNothing);
      expect(find.textContaining('berhasil disimpan'), findsOneWidget);
    },
  );

  testWidgets('EditProductModal confirms before deleting product', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
        child: ExShaBirdShopApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Navigate to Inventaris tab via top bar action
    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();

    // Tap '+' on the first card (Murai Batu Medan)
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    // Tap 'Hapus'
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog
    expect(find.text('Hapus Produk?'), findsOneWidget);
    expect(find.text('Hapus Sekarang'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Hapus Sekarang'));
    await tester.pumpAndSettle();

    // Modal closed and snackbar shown
    expect(find.byType(EditProductModal), findsNothing);
    expect(find.textContaining('berhasil dihapus'), findsOneWidget);
  });

  testWidgets(
    'AddProductModal opens independently without tab switcher and confirms on add',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(SignedInOwner.new),
            shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
          ],
          child: ExShaBirdShopApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Inventaris tab via top bar action
      await tester.tap(find.text('Produk'));
      await tester.pumpAndSettle();

      // Tap '+ Tambah Produk' in App Bar
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pumpAndSettle();

      // Verify independent AddProductModal opened
      expect(find.byType(AddProductModal), findsOneWidget);
      expect(find.text('Tambah Produk Baru'), findsOneWidget);

      // Verify NO tab switcher present in add modal
      expect(find.text('+ Tambah Baru'), findsNothing);
      expect(find.text('Ubah Produk Ini'), findsNothing);

      // Enter product name
      final nameField = find.widgetWithText(
        TextField,
        'Nama Produk / Jenis Avian',
      );
      await tester.enterText(nameField, 'Kenari Yorkshire Super');
      await tester.pumpAndSettle();

      // Tap 'Tambah ke Inventaris'
      await tester.tap(find.text('Tambah ke Inventaris'));
      await tester.pumpAndSettle();

      // Verify confirmation popup dialog appears
      expect(find.text('Tambah Produk Baru?'), findsOneWidget);
      expect(find.text('Ya, Tambahkan'), findsOneWidget);

      // Confirm in dialog
      await tester.tap(find.text('Ya, Tambahkan'));
      await tester.pumpAndSettle();

      // Modal closed and snackbar shown
      expect(find.byType(AddProductModal), findsNothing);
      expect(find.textContaining('berhasil ditambahkan'), findsOneWidget);
    },
  );

  testWidgets(
    'Modals show device image picker options (Camera & Gallery) and NO URL input field',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(SignedInOwner.new),
            shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
          ],
          child: ExShaBirdShopApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Inventaris tab via top bar action
      await tester.tap(find.text('Produk'));
      await tester.pumpAndSettle();

      // Open Edit modal
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      // Verify Device Image Picker is present
      expect(find.text('Foto Produk'), findsOneWidget);
      expect(find.text('Ambil Foto'), findsOneWidget);
      expect(find.text('Pilih dari Galeri'), findsOneWidget);

      // Verify NO URL input field exists
      expect(find.text('URL Foto Produk (opsional)'), findsNothing);
      expect(find.text('URL Gambar'), findsNothing);

      // Close edit modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Open Add modal
      await tester.tap(find.byIcon(Icons.add_box_outlined));
      await tester.pumpAndSettle();

      // Verify Device Image Picker in Add modal
      expect(find.text('Foto Produk'), findsOneWidget);
      expect(find.text('Ambil Foto'), findsOneWidget);
      expect(find.text('Pilih dari Galeri'), findsOneWidget);

      // Verify NO URL input field in Add modal
      expect(find.text('URL Foto Produk (opsional)'), findsNothing);
      expect(find.text('URL Gambar'), findsNothing);
    },
  );
}

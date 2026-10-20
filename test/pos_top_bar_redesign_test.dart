import 'package:birdshop_posapp/providers/session_provider.dart';

import 'auth_test_support.dart';

import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdshop_posapp/main.dart';
import 'package:birdshop_posapp/providers/navigation_provider.dart';

void main() {
  testWidgets(
    'POS Cashier Top Bar renders redesigned layout with integrated searchbar, actions, and NO barcode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ExShaBirdShopApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify NO Barcode / QR Scanner icon exists anywhere
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(find.byTooltip('Pindai Barcode'), findsNothing);

      // 2. Verify integrated search bar inside top bar
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(find.text('Cari produk / SKU...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // 3. Verify filter button INSIDE search bar
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byTooltip('Filter & urutkan'), findsOneWidget);

      expect(find.text('Produk'), findsOneWidget);

      // 5. Test Filter button inside searchbar opens Filter modal
      await tester.tap(find.byTooltip('Filter & urutkan'));
      await tester.pumpAndSettle();

      expect(find.text('Filter & Urutan Katalog'), findsOneWidget);
      expect(find.text('Kategori Produk'), findsOneWidget);
      expect(find.text('Ketersediaan Stok'), findsOneWidget);
      expect(find.text('Urutkan Menurut'), findsOneWidget);

      // Close Filter modal
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // 7. Test Inventaris button switches to Inventaris tab
      await tester.tap(find.text('Produk'));
      await tester.pumpAndSettle();

      expect(container.read(mainNavIndexProvider), equals(1));
      expect(find.text('Nilai aset inventaris'), findsOneWidget);
    },
  );
}

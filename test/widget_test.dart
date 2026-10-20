import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdshop_posapp/main.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/screens/transaction_success_screen.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets('first launch requires Owner setup before exposing POS', (
    tester,
  ) async {
    final container = authContainer(MemoryAuthStore());
    addTearDown(container.dispose);
    await tester.runAsync(() => awaitAuthLoaded(container));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExShaBirdShopApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Siapkan akun Owner'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Murai Batu Medan'), findsNothing);
  });

  testWidgets('authenticated Owner can browse the POS and add to cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
        child: const ExShaBirdShopApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EX-SHA Bird Shop'), findsOneWidget);
    expect(find.text('Produk'), findsOneWidget);
    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Murai Batu Medan'), findsWidgets);
    await tester.tap(find.text('Tambah').first);
    await tester.pumpAndSettle();
    expect(find.text('Keranjang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TransactionSuccessScreen renders receipt', (tester) async {
    final sampleTx = TransactionRecord(
      id: 'TRX-TEST-001',
      timestamp: DateTime(2026, 9, 28, 22, 59),
      items: const [],
      subtotal: 50000,
      memberDiscount: 0,
      tax: 5500,
      totalAmount: 55500,
      paymentMethod: PaymentMethod.tunai,
      receivedAmount: 60000,
      changeAmount: 4500,
      cashierName: 'Ahmad Kasir',
      cashierId: 'KSR-01',
    );
    await tester.pumpWidget(
      MaterialApp(home: TransactionSuccessScreen(transaction: sampleTx)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Transaksi Berhasil!'), findsOneWidget);
    expect(find.text('TRX-TEST-001'), findsWidgets);
  });
}

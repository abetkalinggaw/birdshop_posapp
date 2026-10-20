import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/cart_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';
import 'package:birdshop_posapp/widgets/cashier_shift_gate.dart';
import 'package:birdshop_posapp/widgets/cashier_shift_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

class SignedInCashier extends AuthNotifier {
  @override
  AuthState build() {
    final user = testOwner.copyWith(role: UserRole.cashier);
    return AuthState(users: [user], currentUser: user);
  }
}

void main() {
  for (final size in [
    const Size(320, 640),
    const Size(800, 1000),
    const Size(640, 320),
  ]) {
    testWidgets(
      'open, close with difference, saved summary and history fit $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(SignedInCashier.new),
            shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: CashierShiftGate(
                child: Builder(
                  builder: (context) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => showCashierShiftSheet(
                          context,
                          closing: container.read(sessionProvider).activeShift,
                        ),
                        child: const Text('Close active shift'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Siap mulai shift?'), findsOneWidget);
      await tester.ensureVisible(find.text('Buka Shift'));
      await tester.tap(find.text('Buka Shift'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka Shift & Mulai'));
        await tester.pumpAndSettle();
        expect(container.read(sessionProvider).activeShift, isNull);
        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(find.byType(TextFormField).first, '100000');
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Buka Shift & Mulai'));
        await tester.pumpAndSettle();
        expect(
          container.read(sessionProvider).activeShift!.openingCash,
          100000,
        );
        await tester.tap(find.text('Close active shift'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField).first);
        await tester.enterText(find.byType(TextFormField).first, '95000');
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField).last);
        await tester.enterText(
          find.byType(TextFormField).last,
          'Kas kurang saat penghitungan akhir.',
        );
        await tester.tap(find.text('Simpan & Tutup Shift'));
        await tester.pumpAndSettle();
        expect(find.text('Ringkasan Shift'), findsOneWidget);
        expect(
          container.read(sessionProvider).closedShifts.single.difference,
          -5000,
        );
        await tester.tap(find.text('Selesai'));
        await tester.pumpAndSettle();
        expect(find.text('Siap mulai shift?'), findsOneWidget);
        await tester.ensureVisible(find.text('Riwayat Shift'));
        await tester.tap(find.text('Riwayat Shift'));
        await tester.pumpAndSettle();
        expect(find.textContaining('0 transaksi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'cancel opening preserves state; unfinished cart must be explicitly discarded',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInCashier.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showCashierShiftSheet(
                    context,
                    closing: container.read(sessionProvider).activeShift,
                  ),
                  child: const Text('Shift'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shift'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tutup'));
      await tester.pumpAndSettle();
      expect(container.read(sessionProvider).activeShift, isNull);
      await container.read(sessionProvider.notifier).openNewShift(0);
      container
          .read(cartProvider.notifier)
          .addItem(container.read(inventoryProvider).products.first);
      await tester.tap(find.text('Shift'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Kosongkan Keranjang'));
      await tester.tap(find.text('Kosongkan Keranjang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).items, isNotEmpty);
      await tester.tap(find.text('Kosongkan Keranjang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kosongkan'));
      await tester.pumpAndSettle();
      expect(container.read(cartProvider).items, isEmpty);
      expect(container.read(sessionProvider).isShiftActive, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

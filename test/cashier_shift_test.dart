import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/models/cart_item.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/cart_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/providers/transaction_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_test_support.dart';

class DelayedShiftStore extends MemoryAuthStore {
  Completer<void>? pending;
  @override
  Future<void> write(String value) async {
    await pending?.future;
    await super.write(value);
  }
}

Future<TransactionRecord> sell(
  ProviderContainer container,
  PaymentMethod method,
) {
  final product = container
      .read(inventoryProvider)
      .products
      .firstWhere((p) => p.stock > 0);
  final user = container.read(authProvider).currentUser!;
  return container
      .read(transactionProvider.notifier)
      .createTransaction(
        items: [CartItem(product: product)],
        subtotal: product.price,
        memberDiscount: 0,
        tax: 0,
        totalAmount: product.price,
        paymentMethod: method,
        receivedAmount: product.price,
        changeAmount: 0,
        cashierName: user.name,
        cashierId: user.id,
      );
}

void main() {
  late MemoryAuthStore accounts;
  late MemoryAuthStore shifts;
  late ProviderContainer container;
  late DateTime now;
  setUp(() async {
    accounts = MemoryAuthStore();
    shifts = MemoryAuthStore();
    now = DateTime.utc(2026, 10, 15, 8);
    container = authContainer(accounts, shifts: shifts, now: () => now);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner('Owner', 'owner', '654321');
    await auth.login('owner', '654321', keepLoggedIn: true);
  });

  test('opening is required, permits zero, and rejects duplicate or invalid opening cash', () async {
    final session = container.read(sessionProvider.notifier);
    await expectLater(
      sell(container, PaymentMethod.tunai),
      throwsA(isA<AuthException>()),
    );
    for (final amount in [-1.0, double.nan, double.infinity]) {
      await expectLater(
        session.openNewShift(amount),
        throwsA(isA<AuthException>()),
      );
    }
    final opened = await session.openNewShift(0);
    expect(opened.isOpen, isTrue);
    await expectLater(session.openNewShift(100), throwsA(isA<AuthException>()));
    expect(container.read(sessionProvider).shifts.length, 1);
    expect(jsonDecode(shifts.value!)['shifts'][0]['openingCash'], 0);
  });

  test('cash and non-cash sales persist once, link to shift, and deduct stock once', () async {
    final session = container.read(sessionProvider.notifier);
    final opened = await session.openNewShift(100000);
    final initial = container.read(inventoryProvider).products.first.stock;
    final cash = await sell(container, PaymentMethod.tunai);
    final nonCash = await sell(container, PaymentMethod.qris);
    final active = container.read(sessionProvider).activeShift!;
    expect(cash.shiftId, opened.id);
    expect(active.sales.length, 2);
    expect(active.expectedCash, 100000 + cash.totalAmount);
    expect(active.nonCashSales, nonCash.totalAmount);
    expect(container.read(inventoryProvider).products.first.stock, initial - 2);
    expect(
      container
          .read(visibleTransactionsProvider)
          .where((t) => t.id == cash.id)
          .length,
      1,
    );
    final restored = authContainer(accounts, shifts: shifts, now: () => now);
    addTearDown(restored.dispose);
    await awaitAuthLoaded(restored);
    expect(
      restored.read(sessionProvider).activeShift!.expectedCash,
      active.expectedCash,
    );
    expect(
      restored.read(visibleTransactionsProvider).any((t) => t.id == cash.id),
      isTrue,
    );
    await expectLater(
      restored.read(sessionProvider.notifier).recordSale(cash),
      throwsA(isA<AuthException>()),
    );
  });

  test('closing records actual cash, shortage reason, history, and blocks sales until reopening', () async {
    final session = container.read(sessionProvider.notifier);
    await session.openNewShift(100000);
    await sell(container, PaymentMethod.tunai);
    final expected = container.read(sessionProvider).cashInDrawer;
    await expectLater(
      session.closeShift(expected - 5000),
      throwsA(isA<AuthException>()),
    );
    final closed = await session.closeShift(
      expected - 5000,
      note: 'Selisih saat hitung kas',
    );
    expect(closed.difference, -5000);
    expect(closed.closedAt, now);
    expect(container.read(sessionProvider).activeShift, isNull);
    expect(
      container.read(sessionProvider).closedShifts.single.note,
      'Selisih saat hitung kas',
    );
    await expectLater(
      sell(container, PaymentMethod.tunai),
      throwsA(isA<AuthException>()),
    );
    final restored = authContainer(accounts, shifts: shifts, now: () => now);
    addTearDown(restored.dispose);
    await awaitAuthLoaded(restored);
    expect(
      restored.read(sessionProvider).closedShifts.single.difference,
      -5000,
    );
    final next = await restored.read(sessionProvider.notifier).openNewShift(0);
    expect(next.id, isNot(closed.id));
    expect(next.sales, isEmpty);
    final balanced = await restored
        .read(sessionProvider.notifier)
        .closeShift(0);
    expect(balanced.difference, 0);
  });

  test(
    'unpaid cart prevents closing and cash differences require a note',
    () async {
      final session = container.read(sessionProvider.notifier);
      await session.openNewShift(0);
      container
          .read(cartProvider.notifier)
          .addItem(container.read(inventoryProvider).products.first);
      await expectLater(session.closeShift(0), throwsA(isA<AuthException>()));
      container.read(cartProvider.notifier).clearCart();
      await expectLater(
        session.closeShift(1000),
        throwsA(isA<AuthException>()),
      );
      expect(
        (await session.closeShift(1000, note: 'Uang lebih')).difference,
        1000,
      );
    },
  );

  test(
    'previous-day shift blocks a new shift and sales but allows reconciliation',
    () async {
      final session = container.read(sessionProvider.notifier);
      final opened = await session.openNewShift(25000);
      now = now.add(const Duration(days: 1));
      expect(session.isPreviousDay(opened), isTrue);
      await expectLater(
        sell(container, PaymentMethod.tunai),
        throwsA(isA<AuthException>()),
      );
      await expectLater(session.openNewShift(0), throwsA(isA<AuthException>()));
      await session.closeShift(25000);
      await session.openNewShift(50000);
      expect(container.read(sessionProvider).activeShift!.startedAt, now);
    },
  );

  test('failed saves preserve opening/closing state and never commit a sale or stock deduction', () async {
    final session = container.read(sessionProvider.notifier);
    shifts.failWrites = true;
    await expectLater(
      session.openNewShift(1000),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(sessionProvider).shifts, isEmpty);
    shifts.failWrites = false;
    await session.openNewShift(1000);
    final stock = container.read(inventoryProvider).products.first.stock;
    final count = container.read(transactionProvider).transactions.length;
    shifts.failWrites = true;
    await expectLater(
      sell(container, PaymentMethod.tunai),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(inventoryProvider).products.first.stock, stock);
    expect(container.read(transactionProvider).transactions.length, count);
    expect(container.read(sessionProvider).activeShift!.sales, isEmpty);
    await expectLater(session.closeShift(1000), throwsA(isA<AuthException>()));
    expect(container.read(sessionProvider).isShiftActive, isTrue);
    shifts.failWrites = false;
    await sell(container, PaymentMethod.tunai);
    expect(container.read(sessionProvider).activeShift!.sales.length, 1);
  });

  test(
    'shifts remain isolated by immutable account identity across login changes',
    () async {
      final auth = container.read(authProvider.notifier);
      final session = container.read(sessionProvider.notifier);
      await session.openNewShift(1000);
      await auth.addUser('Employee', 'cashier', '123456', UserRole.cashier, '');
      await auth.logout();
      await auth.login('cashier', '123456');
      expect(container.read(sessionProvider).activeShift, isNull);
      await session.openNewShift(2000);
      await session.closeShift(2000);
      await auth.logout();
      await auth.login('owner', '654321');
      expect(container.read(sessionProvider).activeShift!.openingCash, 1000);
      expect(container.read(sessionProvider).closedShifts, isEmpty);
    },
  );

  test('unreadable shift data fails closed without deleting it', () async {
    shifts.value = '{invalid';
    await container.read(sessionProvider.notifier).load();
    expect(container.read(sessionProvider).error, isNotNull);
    await expectLater(
      container.read(sessionProvider.notifier).openNewShift(0),
      throwsA(isA<AuthException>()),
    );
    expect(shifts.value, '{invalid');
  });

  test(
    'pending sale blocks duplicate sale, stock edits and shift closing',
    () async {
      final delayed = DelayedShiftStore();
      final c = authContainer(accounts, shifts: delayed, now: () => now);
      addTearDown(c.dispose);
      await awaitAuthLoaded(c);
      await c.read(sessionProvider.notifier).openNewShift(0);
      delayed.pending = Completer<void>();
      final first = sell(c, PaymentMethod.tunai);
      await expectLater(
        sell(c, PaymentMethod.tunai),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        c.read(sessionProvider.notifier).closeShift(0),
        throwsA(isA<AuthException>()),
      );
      final p = c.read(inventoryProvider).products.first;
      await expectLater(
        c.read(inventoryProvider.notifier).updateStock(p.sku, 99),
        throwsA(isA<AuthException>()),
      );
      delayed.pending!.complete();
      await first;
      expect(c.read(sessionProvider).activeShift!.sales.length, 1);
    },
  );
}

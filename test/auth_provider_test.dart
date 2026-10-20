import 'dart:convert';

import 'package:birdshop_posapp/models/cart_item.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/cart_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/navigation_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/providers/transaction_provider.dart';
import 'package:birdshop_posapp/services/auth_store.dart';

import 'auth_test_support.dart';

void main() {
  test(
    'first Owner setup, normalized login, persistence and no plaintext PIN',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      expect(container.read(authProvider).needsSetup, isTrue);
      await auth.setupOwner('Owner', 'owner-01', '654321');
      expect(container.read(authProvider).currentUser, isNull);
      expect(store.value, isNot(contains('654321')));
      await auth.login(' owner-01 ', '654321');
      expect(container.read(authProvider).currentUser!.role, UserRole.admin);
      final restored = authContainer(store);
      addTearDown(restored.dispose);
      await awaitAuthLoaded(restored);
      expect(restored.read(authProvider).needsSetup, isFalse);
      expect(restored.read(authProvider).currentUser!.id, 'staff:1');
      await restored.read(authProvider.notifier).login('OWNER-01', '654321');
      expect(restored.read(authProvider).currentUser!.id, 'staff:1');
    },
  );

  test(
    'incorrect PIN and unknown ID fail; fifth failure locks across restart',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      for (var i = 0; i < 4; i++) {
        await expectLater(
          auth.login(i == 0 ? 'UNKNOWN' : 'OWNER-01', '111111'),
          throwsA(isA<AuthException>()),
        );
      }
      await expectLater(
        auth.login('OWNER-01', '111111'),
        throwsA(isA<AuthException>()),
      );
      final restored = authContainer(store);
      addTearDown(restored.dispose);
      await awaitAuthLoaded(restored);
      await expectLater(
        restored.read(authProvider.notifier).login('OWNER-01', '654321'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('Tunggu'),
          ),
        ),
      );
      expect(restored.read(authProvider).currentUser, isNull);
    },
  );

  test(
    'Owner creates staff, duplicate IDs fail, disabled accounts cannot login',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      await auth.login('OWNER-01', '654321');
      await auth.addUser('Employee', 'CASH-01', '123456', UserRole.cashier, '');
      await expectLater(
        auth.addUser('Duplicate', 'cash-01', '123456', UserRole.cashier, ''),
        throwsA(isA<AuthException>()),
      );
      await auth.updateUser(
        accountId(container, 'CASH-01'),
        UserRole.cashier,
        active: false,
      );
      await auth.logout();
      await expectLater(
        auth.login('CASH-01', '123456'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            contains('dinonaktifkan'),
          ),
        ),
      );
    },
  );

  test(
    'cashier can sell, cannot manage stock or staff, and sees only own history',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      await auth.login('OWNER-01', '654321');
      await auth.addUser('Employee', 'CASH-01', '123456', UserRole.cashier, '');
      await auth.logout();
      await auth.login('CASH-01', '123456');
      final inventory = container.read(inventoryProvider.notifier);
      final product = container.read(inventoryProvider).products.first;
      await expectLater(
        inventory.updateStock(product.sku, 200),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        inventory.deleteProduct(product.sku),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        inventory.addProduct(product),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        inventory.updateProduct(product),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.addUser('Other', 'CASH-02', '123456', UserRole.cashier, ''),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.updateUser(accountId(container, 'OWNER-01'), UserRole.cashier),
        throwsA(isA<AuthException>()),
      );
      expect(container.read(visibleTransactionsProvider), isEmpty);
      await container.read(sessionProvider.notifier).openNewShift(0);
      await container
          .read(transactionProvider.notifier)
          .createTransaction(
            items: [CartItem(product: product)],
            subtotal: product.price,
            memberDiscount: 0,
            tax: 0,
            totalAmount: product.price,
            paymentMethod: PaymentMethod.tunai,
            receivedAmount: product.price,
            changeAmount: 0,
            cashierName: 'Employee',
            cashierId: accountId(container, 'CASH-01'),
          );
      expect(container.read(visibleTransactionsProvider).length, 1);
      expect(
        container.read(visibleTransactionsProvider).single.cashierId,
        accountId(container, 'CASH-01'),
      );
      await auth.logout();
      await auth.login('OWNER-01', '654321');
      expect(container.read(visibleTransactionsProvider).length, 4);
    },
  );

  test(
    'PIN changes verify old PIN; Owner can reset a staff PIN and edit role',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      await auth.login('OWNER-01', '654321');
      await expectLater(
        auth.changePin('000000', '222222'),
        throwsA(isA<AuthException>()),
      );
      await auth.changePin('654321', '222222');
      await auth.logout();
      await expectLater(
        auth.login('OWNER-01', '654321'),
        throwsA(isA<AuthException>()),
      );
      await auth.login('OWNER-01', '222222');
      await auth.addUser('Employee', 'CASH-01', '123456', UserRole.cashier, '');
      await auth.updateUser(
        accountId(container, 'CASH-01'),
        UserRole.admin,
        newPin: '333333',
      );
      await auth.logout();
      await auth.login('CASH-01', '333333');
      expect(container.read(authProvider).currentUser!.isAdmin, isTrue);
    },
  );

  test('Owner cannot deactivate or demote the current account', () async {
    final store = MemoryAuthStore();
    final container = authContainer(store);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner('Owner', 'OWNER-01', '654321');
    await auth.login('OWNER-01', '654321');
    await expectLater(
      auth.updateUser(accountId(container, 'OWNER-01'), UserRole.cashier),
      throwsA(isA<AuthException>()),
    );
    await expectLater(
      auth.updateUser(
        accountId(container, 'OWNER-01'),
        UserRole.admin,
        active: false,
      ),
      throwsA(isA<AuthException>()),
    );
    expect(container.read(authProvider).users.single.isActive, isTrue);
  });

  test('logout clears cart including discount, navigation and history visibility; shifts stay with their user', () async {
    final store = MemoryAuthStore();
    final container = authContainer(store);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner('Owner', 'OWNER-01', '654321');
    await auth.login('OWNER-01', '654321');
    await auth.addUser('Employee', 'CASH-01', '123456', UserRole.cashier, '');
    container
        .read(cartProvider.notifier)
        .addItem(container.read(inventoryProvider).products.first);
    container.read(cartProvider.notifier).setMemberDiscount(10);
    container.read(mainNavIndexProvider.notifier).setIndex(3);
    await container.read(sessionProvider.notifier).openNewShift(10000);
    await auth.logout();
    expect(container.read(cartProvider).items, isEmpty);
    expect(container.read(cartProvider).memberDiscountPercentage, 0);
    expect(container.read(mainNavIndexProvider), 0);
    expect(container.read(visibleTransactionsProvider), isEmpty);
    await auth.login('CASH-01', '123456');
    expect(container.read(sessionProvider).cashInDrawer, 0);
    await auth.logout();
    await auth.login('OWNER-01', '654321');
    expect(container.read(sessionProvider).cashInDrawer, 10000);
  });

  test(
    'failed secure-storage writes do not create accounts or authenticate',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      store.failWrites = true;
      await expectLater(
        auth.setupOwner('Owner', 'OWNER-01', '654321'),
        throwsA(isA<AuthException>()),
      );
      expect(container.read(authProvider).users, isEmpty);
      store.failWrites = false;
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      store.failWrites = true;
      await expectLater(
        auth.login('OWNER-01', '654321'),
        throwsA(isA<AuthException>()),
      );
      expect(container.read(authProvider).currentUser, isNull);
    },
  );

  test(
    'unreadable saved accounts fail closed instead of reopening Owner setup',
    () async {
      final store = MemoryAuthStore()..value = '{invalid';
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      expect(container.read(authProvider).storageError, isNotNull);
      expect(container.read(authProvider).needsSetup, isFalse);
      expect(store.value, '{invalid');
    },
  );

  test(
    'Owner profile edits persist and refresh the signed-in account',
    () async {
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'OWNER-01', '654321');
      await auth.login('OWNER-01', '654321');
      await auth.updateUser(
        accountId(container, 'OWNER-01'),
        UserRole.admin,
        name: 'Owner Updated',
        phone: '0812345',
      );
      expect(container.read(authProvider).currentUser!.name, 'Owner Updated');
      final restored = authContainer(store);
      addTearDown(restored.dispose);
      await awaitAuthLoaded(restored);
      expect(restored.read(authProvider).users.single.phone, '0812345');
      expect(restored.read(authProvider).users.single.name, 'Owner Updated');
    },
  );

  test('PIN hashing uses unique salts and verifies correctly', () async {
    const hasher = PinHasher(iterations: 1000);
    final first = await hasher.hash('123456');
    final second = await hasher.hash('123456');
    expect(first['salt'], isNot(second['salt']));
    expect(first['hash'], isNot(second['hash']));
    expect(await hasher.verify('123456', first), isTrue);
    expect(await hasher.verify('000000', first), isFalse);
    expect(jsonEncode(first), isNot(contains('123456')));
  });
}

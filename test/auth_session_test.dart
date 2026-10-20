import 'dart:convert';

import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/cart_provider.dart';
import 'package:birdshop_posapp/providers/inventory_provider.dart';
import 'package:birdshop_posapp/providers/navigation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

class SessionWriteFailStore extends MemoryAuthStore {
  @override
  Future<void> write(String value) async {
    if (jsonDecode(value)['session'] != null) {
      throw StateError('Session save failed');
    }
    await super.write(value);
  }
}

void main() {
  late MemoryAuthStore store;
  late DateTime now;

  Future<ProviderContainer> open() async {
    final container = authContainer(store, now: () => now);
    addTearDown(container.dispose);
    await awaitAuthLoaded(container);
    return container;
  }

  setUp(() {
    store = MemoryAuthStore();
    now = DateTime.utc(2026, 10, 15, 8);
  });

  Future<ProviderContainer> login({bool keep = false}) async {
    final container = await open();
    final auth = container.read(authProvider.notifier);
    await auth.setupOwner('Owner', 'owner', '654321');
    await auth.login('owner', '654321', keepLoggedIn: keep);
    return container;
  }

  test(
    'standard login survives restart without extending its eight-hour deadline',
    () async {
      await login();
      final saved = store.value;
      now = now.add(const Duration(hours: 7, minutes: 59));
      final restored = await open();
      expect(restored.read(authProvider).currentUser!.username, 'owner');
      expect(store.value, saved);
      now = now.add(const Duration(minutes: 1));
      final expired = await open();
      expect(expired.read(authProvider).currentUser, isNull);
      expect(expired.read(authProvider).loginNotice, contains('Sesi berakhir'));
      expect(expired.read(authProvider).needsSetup, isFalse);
    },
  );

  test(
    'kept login survives long closure; explicit logout revokes it on disk',
    () async {
      await login(keep: true);
      now = now.add(const Duration(days: 90));
      final restored = await open();
      final auth = restored.read(authProvider.notifier);
      expect(auth.requireUser().username, 'owner');
      await auth.logout();
      expect(restored.read(authProvider).currentUser, isNull);
      expect(jsonDecode(store.value!)['session'], isNull);
      final signedOut = await open();
      expect(signedOut.read(authProvider).currentUser, isNull);
      expect(signedOut.read(authProvider).loginNotice, isNull);
      await signedOut.read(authProvider.notifier).login('owner', '654321');
      now = now.add(const Duration(hours: 8));
      signedOut.read(authProvider.notifier).checkSession();
      expect(signedOut.read(authProvider).currentUser, isNull);
    },
  );

  test(
    'expired sessions deny protected operations and clear the shared cart',
    () async {
      final container = await login();
      final auth = container.read(authProvider.notifier);
      final product = container.read(inventoryProvider).products.first;
      container.read(cartProvider.notifier).addItem(product);
      container.read(cartProvider.notifier).setMemberDiscount(10);
      container.read(mainNavIndexProvider.notifier).setIndex(3);
      now = now.add(const Duration(hours: 8));
      expect(auth.requireUser, throwsA(isA<AuthException>()));
      expect(container.read(cartProvider).items, isEmpty);
      expect(container.read(cartProvider).memberDiscountPercentage, 0);
      expect(container.read(mainNavIndexProvider), 0);
      await expectLater(
        container.read(inventoryProvider.notifier).updateStock(product.sku, 1),
        throwsA(isA<AuthException>()),
      );
    },
  );

  testWidgets(
    'restored session expires on its timer while the app stays open',
    (tester) async {
      await tester.runAsync(() => login());
      final container = authContainer(store, now: () => now);
      addTearDown(container.dispose);
      container.read(authProvider);
      await tester.pump();
      expect(container.read(authProvider).currentUser, isNotNull);
      now = now.add(const Duration(hours: 8));
      await tester.pump(const Duration(hours: 8));
      expect(container.read(authProvider).currentUser, isNull);
      expect(
        container.read(authProvider).loginNotice,
        contains('Sesi berakhir'),
      );
    },
  );

  test(
    'legacy, malformed, missing and inactive sessions do not bypass login',
    () async {
      final container = await login();
      final original = jsonDecode(store.value!) as Map<String, dynamic>;
      for (final session in [
        null,
        {'userId': 'staff:1', 'keepLoggedIn': true},
        {...original['session'] as Map, 'userId': 'missing'},
        {...original['session'] as Map, 'expiresAt': 'invalid'},
      ]) {
        store.value = jsonEncode({...original, 'session': session});
        final restored = await open();
        expect(restored.read(authProvider).currentUser, isNull);
        expect(restored.read(authProvider).storageError, isNull);
        expect(restored.read(authProvider).needsSetup, isFalse);
      }
      // An active Owner must still exist; only the remembered cashier is disabled.
      store.value = jsonEncode(original);
      await container
          .read(authProvider.notifier)
          .addUser('Employee', 'cashier', '123456', UserRole.cashier, '');
      await container.read(authProvider.notifier).logout();
      await container
          .read(authProvider.notifier)
          .login('cashier', '123456', keepLoggedIn: true);
      final disabled = jsonDecode(store.value!) as Map<String, dynamic>;
      (disabled['users'] as List).last['isActive'] = false;
      store.value = jsonEncode(disabled);
      final restored = await open();
      expect(restored.read(authProvider).currentUser, isNull);
    },
  );

  test(
    'failed logout storage write reports failure and never claims revocation',
    () async {
      final container = await login(keep: true);
      final auth = container.read(authProvider.notifier);
      store.failWrites = true;
      await expectLater(auth.logout(), throwsA(isA<AuthException>()));
      expect(container.read(authProvider).currentUser, isNotNull);
      expect(jsonDecode(store.value!)['session'], isNotNull);
      store.failWrites = false;
      await auth.logout();
      expect((await open()).read(authProvider).currentUser, isNull);
    },
  );

  test(
    'failure saving a new session never authenticates or leaves one on disk',
    () async {
      store = SessionWriteFailStore();
      final container = await open();
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'owner', '654321');
      await expectLater(
        auth.login('owner', '654321', keepLoggedIn: true),
        throwsA(isA<AuthException>()),
      );
      expect(container.read(authProvider).currentUser, isNull);
      expect(jsonDecode(store.value!)['session'], isNull);
      expect((await open()).read(authProvider).currentUser, isNull);
    },
  );
}

import 'package:birdshop_posapp/providers/session_provider.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/main.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/navigation_provider.dart';
import 'package:birdshop_posapp/screens/inventory_screen.dart';
import 'package:birdshop_posapp/screens/user_management_screen.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets(
    'cashier login shows three destinations and logout removes protected routes',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryAuthStore();
      final container = authContainer(store);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await awaitAuthLoaded(container);
        final auth = container.read(authProvider.notifier);
        await auth.setupOwner('Owner', 'OWNER-01', '654321');
        await auth.login('OWNER-01', '654321');
        await auth.addUser(
          'Employee',
          'CASH-01',
          '123456',
          UserRole.cashier,
          '',
        );
        await auth.logout();
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ExShaBirdShopApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke toko'), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.text('Keluar otomatis 8 jam setelah masuk.'), findsOneWidget);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(find.text('Tetap masuk hingga Anda keluar akun.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'CASH-01');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.runAsync(() async {
        await tester.tap(find.text('Masuk'));
        while (container.read(authProvider).currentUser == null) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(jsonDecode(store.value!)['session']['keepLoggedIn'], isTrue);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.destinations.length, 3);
      expect(find.text('Laporan'), findsNothing);
      expect(find.text('Produk'), findsNothing);
      container.read(mainNavIndexProvider.notifier).setIndex(4);
      await tester.pumpAndSettle();
      expect(find.textContaining('Cashier (Employee)'), findsOneWidget);
      expect(find.byTooltip('Kelola Pengguna'), findsNothing);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
      nav.push(
        MaterialPageRoute<void>(builder: (_) => const UserManagementScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses hanya untuk Admin.'), findsOneWidget);
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke toko'), findsOneWidget);
      expect(find.byType(UserManagementScreen), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke toko'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Owner management route handles Android back', (tester) async {
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
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const UserManagementScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UserManagementScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UserManagementScreen), findsNothing);
    expect(find.text('EX-SHA Bird Shop'), findsOneWidget);
  });

  testWidgets('resume expires the session and removes protected routes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 15, 8);
    final container = authContainer(MemoryAuthStore(), now: () => now);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      await awaitAuthLoaded(container);
      final auth = container.read(authProvider.notifier);
      await auth.setupOwner('Owner', 'owner', '654321');
      await auth.login('owner', '654321');
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ExShaBirdShopApp(),
      ),
    );
    await tester.pumpAndSettle();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    nav.push(
      MaterialPageRoute<void>(builder: (_) => const UserManagementScreen()),
    );
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 8));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke toko'), findsOneWidget);
    expect(
      find.text('Sesi berakhir. Masuk kembali untuk melanjutkan.'),
      findsOneWidget,
    );
    expect(find.byType(UserManagementScreen), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Masuk ke toko'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signed-out direct inventory screen denies management', (
    tester,
  ) async {
    final container = authContainer(MemoryAuthStore());
    addTearDown(container.dispose);
    await tester.runAsync(() => awaitAuthLoaded(container));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: InventoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Akses hanya untuk Admin.'), findsOneWidget);
  });
}

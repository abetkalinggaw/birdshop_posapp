import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:birdshop_posapp/main.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/widgets/staff_identity_fields.dart';

import 'auth_test_support.dart';

void main() {
  testWidgets(
    'Owner setup requires gender and submits username plus automatic Staff ID',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
      expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'ID Staff (otomatis)'),
        findsNothing,
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Owner');
      await tester.enterText(fields.at(1), 'abet.owner');
      await tester.enterText(fields.at(2), '654321');
      await tester.enterText(fields.at(3), '654321');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buat akun Owner'));
      await tester.tap(find.text('Buat akun Owner'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih gender.'), findsOneWidget);
      expect(container.read(authProvider).users, isEmpty);
      await tester.ensureVisible(find.byType(StaffGenderField));
      await tester.tap(find.byType(StaffGenderField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laki-laki').last);
      await tester.pumpAndSettle();
      expect(find.text('ADM-10001'), findsOneWidget);
      await tester.ensureVisible(find.text('Buat akun Owner'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Buat akun Owner'));
        for (
          var i = 0;
          i < 500 && container.read(authProvider).users.isEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('Masuk ke toko'), findsOneWidget);
      final user = container.read(authProvider).users.single;
      expect(user.username, 'abet.owner');
      expect(user.gender, StaffGender.male);
      expect(user.staffId, 'ADM-10001');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Owner creates Cashier from consistent username and gender form',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = authContainer(MemoryAuthStore());
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await awaitAuthLoaded(container);
        final auth = container.read(authProvider.notifier);
        await auth.setupOwner(
          'Owner',
          'owner',
          '654321',
          gender: StaffGender.male,
        );
        await auth.login('owner', '654321');
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ExShaBirdShopApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Akun'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kelola Pengguna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah staff'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Cashier Test');
      await tester.enterText(fields.at(1), 'employee.one');
      await tester.ensureVisible(find.byType(StaffGenderField));
      await tester.tap(find.byType(StaffGenderField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Perempuan').last);
      await tester.pumpAndSettle();
      expect(find.text('CSH-20002'), findsOneWidget);
      await tester.enterText(fields.at(3), '123456');
      await tester.enterText(fields.at(4), '123456');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Buat akun staff'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Buat akun staff'));
        for (
          var i = 0;
          i < 500 && container.read(authProvider).users.length < 2;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('@employee.one'), findsOneWidget);
      expect(find.text('CSH-20002 · Perempuan'), findsOneWidget);
      expect(
        container.read(authProvider).users.last.gender,
        StaffGender.female,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final auth = container.read(authProvider.notifier);
        await auth.logout();
        await auth.login('employee.one', '123456');
      });
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        3,
      );
      expect(container.read(authProvider).currentUser!.staffId, 'CSH-20002');
      expect(tester.takeException(), isNull);
    },
  );
}

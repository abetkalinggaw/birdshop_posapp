import 'package:birdshop_posapp/models/cashier_shift.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';
import 'package:birdshop_posapp/providers/printer_provider.dart';
import 'package:birdshop_posapp/screens/owner_shifts_screen.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

final reviewShifts = [
  CashierShift(
    id: 'SHIFT-ANA',
    userId: 'staff:2',
    cashierName: 'Ana',
    startedAt: DateTime(2026, 10, 15, 8),
    openingCash: 100000,
    closedAt: DateTime(2026, 10, 15, 16),
    actualCash: 95000,
    note: 'Selisih saat hitung kas.',
  ),
  CashierShift(
    id: 'SHIFT-BAYU',
    userId: 'staff:3',
    cashierName: 'Bayu',
    startedAt: DateTime(2026, 10, 16, 8),
    openingCash: 200000,
  ),
  CashierShift(
    id: 'SHIFT-OWNER',
    userId: testOwner.id,
    cashierName: testOwner.name,
    startedAt: DateTime(2026, 10, 14, 8),
    openingCash: 0,
    closedAt: DateTime(2026, 10, 14, 16),
    actualCash: 0,
  ),
];

class ReviewSession extends SessionNotifier {
  @override
  SessionState build() =>
      SessionState(currentUser: testOwner, shifts: reviewShifts);
}

class CashierAuth extends AuthNotifier {
  @override
  AuthState build() {
    final user = testOwner.copyWith(role: UserRole.cashier);
    return AuthState(users: [user], currentUser: user);
  }
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, (call) async {
          if (call.method == 'devices') return <Object>[];
          return {'supported': true, 'connected': false, 'paperMm': 58};
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, null),
  );
  for (final size in [const Size(320, 640), const Size(800, 1000)]) {
    testWidgets(
      'owner filters all cashiers, opens read-only summary and can cancel printer selection at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = ProviderContainer(
          overrides: [
            authProvider.overrideWith(SignedInOwner.new),
            sessionProvider.overrideWith(ReviewSession.new),
          ],
        );
        addTearDown(c.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              builder: (_, child) => MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: const TextScaler.linear(1.3),
                ),
                child: child!,
              ),
              home: const OwnerShiftsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('1 shift aktif · 2 ditutup'), findsOneWidget);
        await tester.tap(find.text('Selisih'));
        await tester.pumpAndSettle();
        expect(find.text('1 shift'), findsOneWidget);
        expect(find.text('Bayu'), findsNothing);
        await tester.ensureVisible(find.text('Ana'));
        await tester.tap(find.text('Ana'));
        await tester.pumpAndSettle();
        expect(find.text('Ringkasan Shift'), findsOneWidget);
        expect(find.text('Cetak Ringkasan Shift'), findsOneWidget);
        expect(find.text('Simpan & Tutup Shift'), findsNothing);
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cetak Ringkasan Shift'));
        await tester.pumpAndSettle();
        expect(find.text('Pilih Printer'), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Cetak Ringkasan Shift'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cashier and opening-date filters narrow the saved shift list', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(SignedInOwner.new),
        sessionProvider.overrideWith(ReviewSession.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OwnerShiftsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    expect(find.text('1 shift'), findsOneWidget);
    await tester.tap(find.text('Semua tanggal buka'));
    await tester.pumpAndSettle();
    final pickerContext = tester.element(find.byType(DateRangePickerDialog));
    Navigator.of(pickerContext).pop(
      DateTimeRange(start: DateTime(2026, 10, 16), end: DateTime(2026, 10, 16)),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 shift'), findsOneWidget);
    await tester.tap(find.text('Hapus tanggal'));
    await tester.pumpAndSettle();
    expect(find.text('1 shift'), findsOneWidget);
  });

  testWidgets('cashier cannot view owner shifts or print owner reports', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(CashierAuth.new),
        sessionProvider.overrideWith(ReviewSession.new),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(ownerShiftsProvider), isEmpty);
    expect(
      await c.read(printerProvider.notifier).printShift('SHIFT-ANA'),
      isFalse,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OwnerShiftsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Akses hanya untuk Admin.'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('active shift has no closing-report print action', (
    tester,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authProvider.overrideWith(SignedInOwner.new),
        sessionProvider.overrideWith(ReviewSession.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const OwnerShiftDetailScreen(shiftId: 'SHIFT-BAYU'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Shift aktif · Belum ditutup'), findsOneWidget);
    expect(find.text('Cetak Ringkasan Shift'), findsNothing);
    expect(
      await c.read(printerProvider.notifier).printShift('SHIFT-BAYU'),
      isFalse,
    );
  });
}

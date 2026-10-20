import 'dart:async';
import 'dart:convert';

import 'package:birdshop_posapp/models/cashier_shift.dart';
import 'package:birdshop_posapp/providers/session_provider.dart';

import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/models/user_profile.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/printer_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

class _Cashier extends AuthNotifier {
  @override
  AuthState build() {
    final user = testOwner.copyWith(role: UserRole.cashier);
    return AuthState(users: [user], currentUser: user);
  }
}

TransactionRecord _receipt({String cashierId = 'other-staff'}) =>
    TransactionRecord(
      id: 'PRINT-001',
      timestamp: DateTime(2026, 10, 15),
      items: [],
      subtotal: 10000,
      memberDiscount: 1000,
      tax: 900,
      totalAmount: 9900,
      paymentMethod: PaymentMethod.tunai,
      receivedAmount: 20000,
      changeAmount: 10100,
      cashierName: 'Kasir',
      cashierId: cashierId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> status;
  late List<MethodCall> calls;
  Future<Object?> Function(MethodCall)? intercept;

  setUp(() {
    calls = [];
    intercept = null;
    status = {
      'supported': true,
      'connected': false,
      'paperMm': 58,
      'name': 'Thermal Printer',
      'address': '00:11:22:33:44:55',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, (call) async {
          calls.add(call);
          if (intercept != null && call.method != 'status') {
            return intercept!(call);
          }
          switch (call.method) {
            case 'devices':
              return [
                {'name': status['name'], 'address': status['address']},
              ];
            case 'connect':
              status['connected'] = true;
              return status;
            case 'disconnect':
              status['connected'] = false;
              return status;
            case 'paper':
              status['paperMm'] = (call.arguments as Map)['paperMm'];
              return status;
            case 'status':
              return status;
            default:
              return null;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, null),
  );

  Future<ProviderContainer> container({
    bool cashier = false,
    MemoryAuthStore? ledger,
  }) async {
    final result = ProviderContainer(
      overrides: [
        authProvider.overrideWith(cashier ? _Cashier.new : SignedInOwner.new),
        shiftStoreProvider.overrideWithValue(ledger ?? MemoryAuthStore()),
      ],
    );
    addTearDown(result.dispose);
    result.read(printerProvider);
    await awaitAuthLoaded(result);
    await Future<void>.delayed(Duration.zero);
    return result;
  }

  testWidgets('paired device, paper setting and disconnect use native state', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final scope = await container();
      final printer = scope.read(printerProvider.notifier);
      expect(scope.read(printerProvider).connected, isFalse);
      await printer.loadDevices();
      expect(
        scope.read(printerProvider).devices.single.name,
        'Thermal Printer',
      );
      expect(
        await printer.connect(scope.read(printerProvider).devices.single),
        isTrue,
      );
      await printer.setPaper(80);
      expect(scope.read(printerProvider).paperMm, 80);
      await printer.disconnect();
      expect(scope.read(printerProvider).connected, isFalse);
      expect(
        scope.read(printerProvider).selected?.address,
        '00:11:22:33:44:55',
      );
    });
  });

  for (final error in [
    'Izin Bluetooth ditolak.',
    'Bluetooth nonaktif.',
    'Printer tidak merespons.',
  ]) {
    testWidgets('native failure is recoverable: $error', (tester) async {
      await tester.runAsync(() async {
        final scope = await container();
        intercept = (_) async =>
            throw PlatformException(code: 'printer_error', message: error);
        await scope.read(printerProvider.notifier).loadDevices();
        expect(scope.read(printerProvider).error, error);
        expect(scope.read(printerProvider).busy, isFalse);
        expect(scope.read(printerProvider).uncertain, isFalse);
        expect(calls.where((c) => c.method == 'write'), isEmpty);
      });
    });
  }

  testWidgets(
    'print reconnects, sends receipt once and blocks concurrent jobs',
    (tester) async {
      await tester.runAsync(() async {
        final scope = await container();
        final writeEntered = Completer<void>();
        final finishWrite = Completer<void>();
        intercept = (call) async {
          if (call.method == 'connect') {
            status['connected'] = true;
            return status;
          }
          if (call.method == 'write') {
            final bytes = (call.arguments as Map)['bytes'] as Uint8List;
            expect(bytes.take(5), [27, 64, 27, 97, 0]);
            expect(bytes.length, greaterThan(10000));
            writeEntered.complete();
            await finishWrite.future;
          }
          return null;
        };
        final first = scope
            .read(printerProvider.notifier)
            .printReceipt(_receipt());
        await writeEntered.future.timeout(const Duration(seconds: 10));
        expect(scope.read(printerProvider).busy, isTrue);
        expect(scope.read(printerProvider).message, isNull);
        expect(
          await scope.read(printerProvider.notifier).printReceipt(_receipt()),
          isFalse,
        );
        finishWrite.complete();
        expect(await first, isTrue);
        expect(calls.where((c) => c.method == 'connect'), hasLength(1));
        expect(calls.where((c) => c.method == 'write'), hasLength(1));
        expect(
          scope.read(printerProvider).message,
          contains('Data struk terkirim'),
        );
        expect(scope.read(printerProvider).busy, isFalse);
      });
    },
  );

  testWidgets('write failure stays uncertain and never retries automatically', (
    tester,
  ) async {
    await tester.runAsync(() async {
      status['connected'] = true;
      final scope = await container();
      intercept = (_) async => throw PlatformException(
        code: 'timeout',
        message: 'Koneksi terputus.',
      );
      expect(
        await scope.read(printerProvider.notifier).printReceipt(_receipt()),
        isFalse,
      );
      expect(scope.read(printerProvider).uncertain, isTrue);
      expect(scope.read(printerProvider).connected, isFalse);
      expect(scope.read(printerProvider).message, isNull);
      expect(calls.where((c) => c.method == 'write'), hasLength(1));
      await scope.read(printerProvider.notifier).refresh();
      expect(scope.read(printerProvider).uncertain, isTrue);
      intercept = null;
      await scope.read(printerProvider.notifier).loadDevices();
      expect(scope.read(printerProvider).uncertain, isTrue);
    });
  });

  testWidgets(
    'failed connection sends nothing and does not claim partial output',
    (tester) async {
      await tester.runAsync(() async {
        final scope = await container();
        intercept = (_) async => throw PlatformException(
          code: 'timeout',
          message: 'Printer tidak merespons.',
        );
        expect(
          await scope.read(printerProvider.notifier).printReceipt(_receipt()),
          isFalse,
        );
        expect(scope.read(printerProvider).uncertain, isFalse);
        expect(calls.where((c) => c.method == 'write'), isEmpty);
      });
    },
  );

  testWidgets(
    'cashier may print own receipt but cannot print another staff sale',
    (tester) async {
      await tester.runAsync(() async {
        final scope = await container(cashier: true);
        expect(
          await scope.read(printerProvider.notifier).printReceipt(_receipt()),
          isFalse,
        );
        expect(
          scope.read(printerProvider).error,
          contains('transaksi sendiri'),
        );
        expect(
          calls.where((c) => c.method == 'connect' || c.method == 'write'),
          isEmpty,
        );
        expect(
          await scope
              .read(printerProvider.notifier)
              .printReceipt(_receipt(cashierId: testOwner.cashierCode)),
          isTrue,
        );
        expect(calls.where((c) => c.method == 'write'), hasLength(1));
      });
    },
  );

  testWidgets('native disconnect event updates shared connection state', (
    tester,
  ) async {
    final scope = await tester.runAsync(container);
    const codec = StandardMethodCodec();
    ServicesBinding.instance.channelBuffers.push(
      thermalPrinterChannel.name,
      codec.encodeMethodCall(
        MethodCall('statusChanged', {...status, 'connected': true}),
      ),
      (_) {},
    );
    await tester.pump();
    expect(scope!.read(printerProvider).connected, isTrue);
    ServicesBinding.instance.channelBuffers.push(
      thermalPrinterChannel.name,
      codec.encodeMethodCall(
        MethodCall('statusChanged', {...status, 'connected': false}),
      ),
      (_) {},
    );
    await tester.pump();
    expect(scope.read(printerProvider).connected, isFalse);
  });

  testWidgets('test print uses the real transport without creating a sale', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final scope = await container();
      expect(await scope.read(printerProvider.notifier).printTest(), isTrue);
      expect(calls.where((call) => call.method == 'write'), hasLength(1));
      expect(
        scope.read(printerProvider).message,
        contains('Data struk terkirim'),
      );
    });
  });
  testWidgets(
    'Owner closing report uses saved shift through native transport once; invalid shifts send nothing',
    (tester) async {
      await tester.runAsync(() async {
        final shift = CashierShift(
          id: 'CLOSED-1',
          userId: 'other',
          cashierName: 'Ana',
          startedAt: DateTime(2026, 10, 16, 8),
          openingCash: 100000,
          closedAt: DateTime(2026, 10, 16, 16),
          actualCash: 95000,
          note: 'Selisih akhir',
        );
        final ledger = MemoryAuthStore()
          ..value = jsonEncode({
            'schemaVersion': 1,
            'shifts': [shift.toJson()],
          });
        final scope = await container(ledger: ledger);
        final printer = scope.read(printerProvider.notifier);
        expect(await printer.printShift('missing'), isFalse);
        expect(calls.where((c) => c.method == 'write'), isEmpty);
        expect(await printer.printShift('CLOSED-1'), isTrue);
        expect(calls.where((c) => c.method == 'write'), hasLength(1));
        expect(
          scope.read(printerProvider).message,
          contains('Data ringkasan shift terkirim'),
        );
        expect(scope.read(sessionProvider).shifts.single.actualCash, 95000);
        expect(scope.read(sessionProvider).shifts.single.sales, isEmpty);
      });
    },
  );
}

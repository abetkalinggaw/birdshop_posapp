import 'package:birdshop_posapp/providers/session_provider.dart';

import 'dart:async';

import 'package:birdshop_posapp/models/cart_item.dart';
import 'package:birdshop_posapp/models/product.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/providers/auth_provider.dart';
import 'package:birdshop_posapp/providers/transaction_provider.dart';
import 'package:birdshop_posapp/screens/receipt_print_screen.dart';
import 'package:birdshop_posapp/screens/transaction_history_screen.dart';
import 'package:birdshop_posapp/screens/transaction_success_screen.dart';
import 'package:birdshop_posapp/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:birdshop_posapp/providers/printer_provider.dart';
import 'package:birdshop_posapp/widgets/printer_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_test_support.dart';

TransactionRecord receipt({bool empty = false}) => TransactionRecord(
  id: 'TRX-RECEIPT-TEST-001',
  timestamp: DateTime(2026, 10, 15, 10, 30),
  items: empty
      ? []
      : [
          CartItem(
            product: const Product(
              sku: 'VOER-001',
              name: 'Voer Topsong Ekstra Premium Kemasan Besar untuk Burung Kicau',
              category: 'Pakan & Voer',
              price: 25000,
              stock: 10,
              minStock: 2,
              imageUrl: '',
            ),
            quantity: 2,
          ),
        ],
  subtotal: 50000,
  memberDiscount: 5000,
  tax: 4500,
  totalAmount: 49500,
  paymentMethod: PaymentMethod.tunai,
  receivedAmount: 100000,
  changeAmount: 50500,
  cashierName: 'Cashier With A Long Name',
  cashierId: 'CSH-20002',
);

Future<void> pumpPrinterApp(WidgetTester tester, Widget widget) async {
  final scope = ProviderContainer(
    overrides: [
      authProvider.overrideWith(SignedInOwner.new),
      shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
    ],
  );
  addTearDown(scope.dispose);
  await scope.read(printerProvider.notifier).refresh();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: scope, child: widget),
  );
}

ProviderContainer printerScope(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(PrinterFeedback).last),
    );

Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; !done() && i < 500; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done(), isTrue);
}

Future<void> finishJob(WidgetTester tester) async {
  final scope = printerScope(tester);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await pumpUntil(tester, () {
    final printer = scope.read(printerProvider);
    return !printer.busy && (printer.message != null || printer.error != null);
  });
  await tester.pumpAndSettle();
}

void progress(int sent, int total) {
  ServicesBinding.instance.channelBuffers.push(
    thermalPrinterChannel.name,
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('writeProgress', {'sent': sent, 'total': total}),
    ),
    (_) {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late int writes;
  late Map<String, dynamic> status;
  Future<void> Function()? write;
  var failConnect = false;
  setUp(() {
    writes = 0;
    write = null;
    failConnect = false;
    status = {
      'supported': true,
      'connected': true,
      'paperMm': 58,
      'name': 'Thermal Test',
      'address': '00:11:22:33:44:55',
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, (call) async {
          switch (call.method) {
            case 'write':
              writes++;
              await write?.call();
              return null;
            case 'devices':
              return [
                {'name': 'Thermal Test', 'address': '00:11:22:33:44:55'},
              ];
            case 'connect':
              if (failConnect) {
                throw PlatformException(
                  code: 'timeout',
                  message: 'Printer tidak merespons.',
                );
              }
              status.addAll({
                'connected': true,
                'name': 'Thermal Test',
                'address': '00:11:22:33:44:55',
              });
              return status;
            case 'paper':
              status['paperMm'] = (call.arguments as Map)['paperMm'];
              return status;
            default:
              return status;
          }
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(thermalPrinterChannel, null),
  );

  testWidgets(
    'invoice follows write progress, waits for completion, then reprints explicitly',
    (tester) async {
      final finish = Completer<void>();
      write = () => writes == 1 ? finish.future : Future<void>.value();
      await pumpPrinterApp(
        tester,
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ReceiptPrintScreen(transaction: receipt()),
        ),
      );
      double feed() => tester
          .widget<Align>(find.byKey(const ValueKey('receipt-feed')))
          .heightFactor!;
      await pumpUntil(tester, () => writes == 1);
      expect(feed(), 0);
      progress(25, 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(feed(), closeTo(.25, .01));
      await tester.pump(const Duration(seconds: 3));
      expect(feed(), closeTo(.25, .01));
      expect(find.text('Data struk terkirim'), findsNothing);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      progress(100, 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(feed(), lessThan(1));
      finish.complete();
      await finishJob(tester);
      expect(feed(), 1);
      expect(find.text('Ulangi Cetak'), findsOneWidget);
      expect(find.text('Pilih Printer'), findsNothing);
      expect(find.byTooltip('Pengaturan printer'), findsOneWidget);
      expect(find.text('Rp 49.500'), findsOneWidget);
      expect(find.text('Rp 50.500'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(writes, 1);
      await tester.tap(find.text('Ulangi Cetak'));
      await tester.pump();
      await finishJob(tester);
      expect(writes, 2);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 640), const Size(800, 1000)]) {
    testWidgets('receipt fits $size with large text and reduced motion', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpPrinterApp(
        tester,
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: ReceiptPrintScreen(transaction: receipt()),
        ),
      );
      await finishJob(tester);
      expect(
        tester
            .widget<Align>(find.byKey(const ValueKey('receipt-feed')))
            .heightFactor,
        1,
      );
      await tester.scrollUntilVisible(
        find.text('Kembalian'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Rp 50.500').hitTestable(), findsOneWidget);
      expect(find.text('Ulangi Cetak').hitTestable(), findsOneWidget);
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty receipt remains readable after automatic print', (
    tester,
  ) async {
    await pumpPrinterApp(
      tester,
      MaterialApp(home: ReceiptPrintScreen(transaction: receipt(empty: true))),
    );
    await finishJob(tester);
    expect(find.text('Tidak ada rincian item.'), findsOneWidget);
    expect(writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'gear keeps printer settings, paper selection and test printing',
    (tester) async {
      await pumpPrinterApp(
        tester,
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: ReceiptPrintScreen(transaction: receipt()),
        ),
      );
      await finishJob(tester);
      await tester.tap(find.byTooltip('Pengaturan printer'));
      await tester.pumpAndSettle();
      expect(find.text('Printer Thermal'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('80 mm · 576 dot').last);
      await tester.pumpAndSettle();
      expect(status['paperMm'], 80);
      await tester.ensureVisible(find.text('Tes Cetak'));
      await tester.tap(find.text('Tes Cetak'));
      await tester.pump();
      await finishJob(tester);
      expect(writes, 2);
      expect(printerScope(tester).read(printerProvider).error, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  Future<void> openSuccessPicker(WidgetTester tester) async {
    await tester.scrollUntilVisible(find.text('Cetak Struk Thermal'), 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cetak Struk Thermal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cetak Struk Thermal'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'success chooses printer before navigation; cancel sends nothing',
    (tester) async {
      final tx = receipt();
      await pumpPrinterApp(
        tester,
        MaterialApp(home: TransactionSuccessScreen(transaction: tx)),
      );
      await tester.pumpAndSettle();
      await openSuccessPicker(tester);
      expect(find.text('Pilih Printer'), findsOneWidget);
      expect(find.byType(ReceiptPrintScreen), findsNothing);
      expect(writes, 0);
      await tester.tap(find.byTooltip('Tutup pengaturan printer'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      await openSuccessPicker(tester);
      await tester.ensureVisible(find.text('Lanjut Cetak Struk'));
      await tester.tap(find.text('Lanjut Cetak Struk'));
      await tester.pump(const Duration(milliseconds: 400));
      await finishJob(tester);
      expect(
        tester
            .widget<ReceiptPrintScreen>(find.byType(ReceiptPrintScreen))
            .transaction,
        same(tx),
      );
      expect(writes, 1);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Transaksi Berhasil!'), findsOneWidget);
      expect(writes, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed printer connection keeps picker open and never prints', (
    tester,
  ) async {
    status.remove('address');
    status.remove('name');
    status['connected'] = false;
    failConnect = true;
    await pumpPrinterApp(
      tester,
      MaterialApp(home: TransactionSuccessScreen(transaction: receipt())),
    );
    await tester.pumpAndSettle();
    await openSuccessPicker(tester);
    await tester.ensureVisible(find.text('Hubungkan'));
    await tester.tap(find.text('Hubungkan'));
    await tester.pumpAndSettle();
    expect(find.text('Printer tidak merespons.'), findsOneWidget);
    expect(find.byType(ReceiptPrintScreen), findsNothing);
    expect(writes, 0);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton).last).onPressed,
      isNull,
    );
  });

  testWidgets(
    'failed transfer stops partial paper and allows an explicit retry',
    (tester) async {
      final finish = Completer<void>();
      write = () => finish.future;
      await pumpPrinterApp(
        tester,
        MaterialApp(home: ReceiptPrintScreen(transaction: receipt())),
      );
      await pumpUntil(tester, () => writes == 1);
      progress(40, 100);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      finish.completeError(
        PlatformException(code: 'timeout', message: 'Koneksi terputus.'),
      );
      await finishJob(tester);
      expect(
        tester
            .widget<Align>(find.byKey(const ValueKey('receipt-feed')))
            .heightFactor,
        closeTo(.4, .01),
      );
      expect(find.textContaining('Sebagian struk mungkin'), findsOneWidget);
      expect(find.text('Data struk terkirim'), findsNothing);
      expect(find.text('Ulangi Cetak'), findsOneWidget);
      expect(writes, 1);
    },
  );

  testWidgets(
    'history uses the same printer-first flow without changing the sale',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(SignedInOwner.new),
          shiftStoreProvider.overrideWithValue(MemoryAuthStore()),
        ],
      );
      addTearDown(container.dispose);
      final before = container.read(transactionProvider);
      final tx = before.transactions.first;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: TransactionHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(tx.id));
      await tester.tap(find.text(tx.id));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cetak struk'));
      await tester.tap(find.text('Cetak struk'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih Printer'), findsOneWidget);
      expect(find.byType(ReceiptPrintScreen), findsNothing);
      expect(writes, 0);
      await tester.ensureVisible(find.text('Lanjut Cetak Struk'));
      await tester.tap(find.text('Lanjut Cetak Struk'));
      await tester.pump(const Duration(milliseconds: 400));
      await finishJob(tester);
      expect(
        tester
            .widget<ReceiptPrintScreen>(find.byType(ReceiptPrintScreen))
            .transaction,
        same(tx),
      );
      expect(container.read(transactionProvider), same(before));
      expect(writes, 1);
      await tester.tap(find.byTooltip('Kembali'));
      await tester.pumpAndSettle();
      expect(find.byType(TransactionHistoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

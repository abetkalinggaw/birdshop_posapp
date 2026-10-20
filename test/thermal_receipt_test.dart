import 'dart:typed_data';

import 'package:birdshop_posapp/models/cart_item.dart';
import 'package:birdshop_posapp/models/cashier_shift.dart';
import 'package:birdshop_posapp/models/product.dart';
import 'package:birdshop_posapp/models/transaction.dart';
import 'package:birdshop_posapp/services/thermal_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void verifyRaster(Uint8List bytes, int width) {
  expect(bytes.take(5), [27, 64, 27, 97, 0]);
  var offset = 5;
  var rows = 0;
  var ink = 0;
  while (offset < bytes.length - 3) {
    expect(bytes.sublist(offset, offset + 4), [29, 118, 48, 0]);
    final rowBytes = bytes[offset + 4] + bytes[offset + 5] * 256;
    final height = bytes[offset + 6] + bytes[offset + 7] * 256;
    expect(rowBytes * 8, width);
    expect(height, inInclusiveRange(1, 128));
    final end = offset + 8 + rowBytes * height;
    expect(end, lessThanOrEqualTo(bytes.length - 3));
    ink += bytes.sublist(offset + 8, end).where((p) => p != 0).length;
    rows += height;
    offset = end;
  }
  expect(bytes.sublist(offset), [27, 100, 4]);
  expect(rows, greaterThan(100));
  expect(ink, greaterThan(100));
}

void main() {
  for (final paper in [58, 80]) {
    testWidgets(
      '$paper mm receipt encodes complete bounded ESC/POS raster bands',
      (tester) async {
        final transaction = TransactionRecord(
          id: 'TRX-THERMAL',
          timestamp: DateTime(2026, 10, 15),
          items: [
            CartItem(
              product: Product(
                sku: 'TEST',
                name: '${'Very long café 鸟 name ' * 15}\nwith symbols × −',
                category: 'Pakan',
                price: 50000,
                stock: 3,
                minStock: 1,
                imageUrl: '',
              ),
              quantity: 2,
            ),
          ],
          subtotal: 100000,
          memberDiscount: 5000,
          tax: 10450,
          totalAmount: 105450,
          paymentMethod: PaymentMethod.tunai,
          receivedAmount: 150000,
          changeAmount: 44550,
          cashierName: 'Kasir Café',
          cashierId: 'CSH-20002',
        );
        await tester.runAsync(() async {
          verifyRaster(
            await buildThermalReceipt(transaction, paper),
            paper == 58 ? 384 : 576,
          );
          verifyRaster(await buildThermalTest(paper), paper == 58 ? 384 : 576);
          verifyRaster(
            await buildThermalShiftReport(
              CashierShift(
                id: 'SHIFT-REPORT',
                userId: 'staff:1',
                cashierName: 'Kasir Panjang ' * 8,
                startedAt: DateTime(2026, 10, 15, 8),
                openingCash: 100000,
                closedAt: DateTime(2026, 10, 15, 16),
                actualCash: 95000,
                note: 'Catatan hitung akhir ' * 20,
              ),
              paper,
            ),
            paper == 58 ? 384 : 576,
          );
        });
      },
    );
  }
  testWidgets('unsupported paper size fails before output', (tester) async {
    await expectLater(buildThermalTest(72), throwsArgumentError);
  });
}

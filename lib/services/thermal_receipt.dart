import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../models/cashier_shift.dart';
import '../widgets/currency_formatter.dart';

Future<Uint8List> buildThermalReceipt(
  TransactionRecord transaction,
  int paperMm,
) async {
  final receipt = _RasterReceipt(paperMm);
  await receipt.text('EX-SHA Bird Shop', center: true, bold: true, large: true);
  await receipt.text(
    'Pasar Burung Pramuka Lt. 1 No. 42\nTelp: 0812-3456-7890',
    center: true,
  );
  await receipt.rule();
  await receipt.text(transaction.id, center: true, bold: true);
  await receipt.text(
    DateFormat('dd/MM/yyyy HH:mm').format(transaction.timestamp),
    center: true,
  );
  await receipt.row('Kasir', transaction.cashierName);
  await receipt.row('ID kasir', transaction.cashierId);
  await receipt.row('Pembayaran', transaction.paymentMethod.code);
  await receipt.rule();
  for (final item in transaction.items) {
    await receipt.text(item.product.name, bold: true);
    await receipt.row(
      '${item.quantity} x ${CurrencyFormatter.format(item.product.price)}',
      CurrencyFormatter.format(item.subtotal),
    );
  }
  if (transaction.items.isEmpty) await receipt.text('Tidak ada rincian item.');
  await receipt.rule();
  await receipt.row('Subtotal', CurrencyFormatter.format(transaction.subtotal));
  if (transaction.memberDiscount > 0) {
    await receipt.row(
      'Diskon member',
      '- ${CurrencyFormatter.format(transaction.memberDiscount)}',
    );
  }
  if (transaction.tax > 0) {
    await receipt.row('Pajak', CurrencyFormatter.format(transaction.tax));
  }
  await receipt.text('Total pembayaran', bold: true);
  await receipt.text(
    CurrencyFormatter.format(transaction.totalAmount),
    bold: true,
    large: true,
  );
  await receipt.row(
    'Dibayar',
    CurrencyFormatter.format(transaction.receivedAmount),
  );
  await receipt.row(
    'Kembalian',
    CurrencyFormatter.format(transaction.changeAmount),
  );
  await receipt.rule();
  await receipt.text(
    'Terima kasih atas kunjungan Anda',
    center: true,
    bold: true,
  );
  await receipt.text('Barang yang dibeli tidak dapat ditukar', center: true);
  return receipt.finish();
}

Future<Uint8List> buildThermalShiftReport(
  CashierShift shift,
  int paperMm,
) async {
  if (shift.isOpen || shift.actualCash == null) {
    throw StateError('Shift belum ditutup.');
  }
  final receipt = _RasterReceipt(paperMm);
  final date = DateFormat('dd/MM/yyyy HH:mm');
  await receipt.text('EX-SHA Bird Shop', center: true, bold: true, large: true);
  await receipt.text('RINGKASAN TUTUP SHIFT', center: true, bold: true);
  await receipt.rule();
  await receipt.text(shift.id, center: true);
  await receipt.row('Kasir', shift.cashierName);
  await receipt.row('Buka', date.format(shift.startedAt.toLocal()));
  await receipt.row('Tutup', date.format(shift.closedAt!.toLocal()));
  await receipt.rule();
  await receipt.row('Modal awal', CurrencyFormatter.format(shift.openingCash));
  await receipt.row(
    'Penjualan tunai',
    CurrencyFormatter.format(shift.cashSales),
  );
  await receipt.row('Non-tunai', CurrencyFormatter.format(shift.nonCashSales));
  await receipt.row(
    'Kas diharapkan',
    CurrencyFormatter.format(shift.expectedCash),
  );
  await receipt.row('Kas aktual', CurrencyFormatter.format(shift.actualCash!));
  await receipt.text(
    shift.difference!.abs() < .005
        ? 'Kas sesuai'
        : shift.difference! < 0
        ? 'Kas kurang'
        : 'Kas lebih',
    bold: true,
  );
  await receipt.text(
    CurrencyFormatter.format(shift.difference!.abs()),
    bold: true,
    large: true,
  );
  await receipt.row('Transaksi', '${shift.sales.length}');
  if (shift.note.isNotEmpty) {
    await receipt.rule();
    await receipt.text('Catatan', bold: true);
    await receipt.text(shift.note);
  }
  await receipt.rule();
  await receipt.text('Ringkasan tersimpan di perangkat ini', center: true);
  return receipt.finish();
}

Future<Uint8List> buildThermalTest(int paperMm) async {
  final receipt = _RasterReceipt(paperMm);
  await receipt.text('EX-SHA Bird Shop', center: true, bold: true, large: true);
  await receipt.text('TES CETAK · $paperMm mm', center: true, bold: true);
  await receipt.rule();
  await receipt.row('Jumlah', 'Rp 1.234.567');
  await receipt.text(
    'Pastikan teks dan garis terbaca utuh.\nIni bukan transaksi penjualan.',
    center: true,
  );
  return receipt.finish();
}

class _RasterReceipt {
  final int width;
  final _bytes = BytesBuilder(copy: false)..add([27, 64, 27, 97, 0]);

  _RasterReceipt(int paperMm)
    : width = switch (paperMm) {
        58 => 384,
        80 => 576,
        _ => throw ArgumentError.value(paperMm, 'paperMm', 'Use 58 or 80 mm'),
      };

  TextPainter _painter(
    String text,
    double maxWidth, {
    bool bold = false,
    bool large = false,
    TextAlign align = TextAlign.left,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'Satoshi',
        fontSize: large ? 32 : 24,
        height: 1.3,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: const Color(0xFF000000),
      ),
    ),
    textDirection: ui.TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: maxWidth, maxWidth: maxWidth);

  Future<void> text(
    String text, {
    bool center = false,
    bool bold = false,
    bool large = false,
  }) async {
    final painter = _painter(
      text,
      width - 24,
      bold: bold,
      large: large,
      align: center ? TextAlign.center : TextAlign.left,
    );
    try {
      await _raster(
        (painter.height + 16).ceil(),
        (canvas) => painter.paint(canvas, const Offset(12, 8)),
      );
    } finally {
      painter.dispose();
    }
  }

  Future<void> row(String label, String value) async {
    final available = width - 36.0;
    final left = _painter(label, available * .5);
    final right = _painter(
      value,
      available * .5,
      bold: true,
      align: TextAlign.right,
    );
    try {
      await _raster((math.max(left.height, right.height) + 12).ceil(), (
        canvas,
      ) {
        left.paint(canvas, const Offset(12, 6));
        right.paint(canvas, Offset(24 + available * .5, 6));
      });
    } finally {
      left.dispose();
      right.dispose();
    }
  }

  Future<void> rule() => _raster(
    24,
    (canvas) => canvas.drawRect(
      Rect.fromLTWH(12, 12, width - 24.0, 2),
      Paint()..color = const Color(0xFF000000),
    ),
  );

  Future<void> _raster(int height, void Function(Canvas) paint) async {
    // Render bands so long receipts never exceed the GPU's image-height limit.
    for (var top = 0; top < height; top += 128) {
      final bandHeight = math.min(128, height - top);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawColor(const Color(0xFFFFFFFF), BlendMode.src)
        ..translate(0, -top.toDouble());
      paint(canvas);
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, bandHeight);
      try {
        final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (rgba == null) throw StateError('Receipt rasterization failed');
        final rowBytes = width ~/ 8;
        final pixels = Uint8List(rowBytes * bandHeight);
        for (var y = 0; y < bandHeight; y++) {
          for (var x = 0; x < width; x++) {
            final i = (y * width + x) * 4;
            if (rgba.getUint8(i) < 160) {
              pixels[y * rowBytes + x ~/ 8] |= 128 >> (x % 8);
            }
          }
        }
        _bytes.add([
          29,
          118,
          48,
          0,
          rowBytes & 255,
          rowBytes >> 8,
          bandHeight & 255,
          bandHeight >> 8,
        ]);
        _bytes.add(pixels);
      } finally {
        image.dispose();
        picture.dispose();
      }
    }
  }

  Uint8List finish() => (_bytes..add([27, 100, 4])).takeBytes();
}

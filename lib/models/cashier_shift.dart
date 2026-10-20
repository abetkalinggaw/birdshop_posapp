import 'transaction.dart';

class CashierShift {
  final String id, userId, cashierName;
  final DateTime startedAt;
  final double openingCash;
  final List<TransactionRecord> sales;
  final DateTime? closedAt;
  final double? actualCash;
  final String note;

  const CashierShift({
    required this.id,
    required this.userId,
    required this.cashierName,
    required this.startedAt,
    required this.openingCash,
    this.sales = const [],
    this.closedAt,
    this.actualCash,
    this.note = '',
  });

  bool get isOpen => closedAt == null;
  double get cashSales => sales
      .where((t) => t.paymentMethod == PaymentMethod.tunai)
      .fold(0, (sum, t) => sum + t.totalAmount);
  double get nonCashSales => sales
      .where((t) => t.paymentMethod != PaymentMethod.tunai)
      .fold(0, (sum, t) => sum + t.totalAmount);
  double get expectedCash => openingCash + cashSales;
  double? get difference =>
      actualCash == null ? null : actualCash! - expectedCash;

  CashierShift copyWith({
    List<TransactionRecord>? sales,
    DateTime? closedAt,
    double? actualCash,
    String? note,
  }) => CashierShift(
    id: id,
    userId: userId,
    cashierName: cashierName,
    startedAt: startedAt,
    openingCash: openingCash,
    sales: sales ?? this.sales,
    closedAt: closedAt ?? this.closedAt,
    actualCash: actualCash ?? this.actualCash,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'cashierName': cashierName,
    'startedAt': startedAt.toIso8601String(),
    'openingCash': openingCash,
    'sales': sales.map((t) => t.toJson()).toList(),
    'closedAt': closedAt?.toIso8601String(),
    'actualCash': actualCash,
    'note': note,
  };

  factory CashierShift.fromJson(Map<String, dynamic> json) {
    final shift = CashierShift(
      id: json['id'] as String,
      userId: json['userId'] as String,
      cashierName: json['cashierName'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String),
      openingCash: (json['openingCash'] as num).toDouble(),
      sales: (json['sales'] as List)
          .map(
            (t) =>
                TransactionRecord.fromJson(Map<String, dynamic>.from(t as Map)),
          )
          .toList(),
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
      actualCash: (json['actualCash'] as num?)?.toDouble(),
      note: json['note'] as String,
    );
    if (shift.id.isEmpty ||
        shift.userId.isEmpty ||
        !shift.openingCash.isFinite ||
        shift.openingCash < 0 ||
        (shift.isOpen != (shift.actualCash == null)) ||
        (shift.actualCash != null &&
            (!shift.actualCash!.isFinite || shift.actualCash! < 0)) ||
        (shift.closedAt?.isBefore(shift.startedAt) ?? false) ||
        shift.sales.any(
          (t) =>
              t.shiftId != shift.id ||
              t.cashierId != shift.userId ||
              t.timestamp.isBefore(shift.startedAt) ||
              !t.totalAmount.isFinite ||
              t.totalAmount < 0,
        ) ||
        shift.sales.map((t) => t.id).toSet().length != shift.sales.length) {
      throw const FormatException('Invalid shift');
    }
    return shift;
  }
}

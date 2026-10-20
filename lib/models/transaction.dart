import 'cart_item.dart';
import 'product.dart';

enum PaymentMethod {
  tunai('Tunai (Cash)', 'TUNAI'),
  qris('QRIS Instant', 'QRIS'),
  transfer('Transfer Bank', 'TRANSFER');

  final String label;
  final String code;
  const PaymentMethod(this.label, this.code);
}

class TransactionRecord {
  final String id;
  final DateTime timestamp;
  final List<CartItem> items;
  final double subtotal;
  final double memberDiscount;
  final double tax;
  final double totalAmount;
  final PaymentMethod paymentMethod;
  final double receivedAmount;
  final double changeAmount;
  final String cashierName;
  final String cashierId;
  final bool isSynced;
  final String? shiftId;

  const TransactionRecord({
    required this.id,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    required this.memberDiscount,
    required this.tax,
    required this.totalAmount,
    required this.paymentMethod,
    required this.receivedAmount,
    required this.changeAmount,
    required this.cashierName,
    required this.cashierId,
    this.isSynced = true,
    this.shiftId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'items': items
        .map((i) => {'product': i.product.toJson(), 'quantity': i.quantity})
        .toList(),
    'subtotal': subtotal,
    'memberDiscount': memberDiscount,
    'tax': tax,
    'totalAmount': totalAmount,
    'paymentMethod': paymentMethod.name,
    'receivedAmount': receivedAmount,
    'changeAmount': changeAmount,
    'cashierName': cashierName,
    'cashierId': cashierId,
    'isSynced': isSynced,
    'shiftId': shiftId,
  };

  factory TransactionRecord.fromJson(Map<String, dynamic> json) =>
      TransactionRecord(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        items: (json['items'] as List)
            .map(
              (i) => CartItem(
                product: Product.fromJson(
                  Map<String, dynamic>.from(i['product'] as Map),
                ),
                quantity: i['quantity'] as int,
              ),
            )
            .toList(),
        subtotal: (json['subtotal'] as num).toDouble(),
        memberDiscount: (json['memberDiscount'] as num).toDouble(),
        tax: (json['tax'] as num).toDouble(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
        paymentMethod: PaymentMethod.values.byName(
          json['paymentMethod'] as String,
        ),
        receivedAmount: (json['receivedAmount'] as num).toDouble(),
        changeAmount: (json['changeAmount'] as num).toDouble(),
        cashierName: json['cashierName'] as String,
        cashierId: json['cashierId'] as String,
        isSynced: json['isSynced'] as bool,
        shiftId: json['shiftId'] as String?,
      );
}

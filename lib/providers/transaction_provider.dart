import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import 'auth_provider.dart';
import 'session_provider.dart';

class TransactionState {
  final List<TransactionRecord> transactions;
  final TransactionRecord? currentCompletedTransaction;

  const TransactionState({
    required this.transactions,
    this.currentCompletedTransaction,
  });

  TransactionState copyWith({
    List<TransactionRecord>? transactions,
    TransactionRecord? currentCompletedTransaction,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      currentCompletedTransaction:
          currentCompletedTransaction ?? this.currentCompletedTransaction,
    );
  }

  double get todayGrossTurnover {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              t.timestamp.year == now.year &&
              t.timestamp.month == now.month &&
              t.timestamp.day == now.day,
        )
        .fold(0.0, (sum, t) => sum + t.totalAmount);
  }

  int get todayTransactionCount {
    final now = DateTime.now();
    return transactions
        .where(
          (t) =>
              t.timestamp.year == now.year &&
              t.timestamp.month == now.month &&
              t.timestamp.day == now.day,
        )
        .length;
  }
}

class TransactionNotifier extends Notifier<TransactionState> {
  static final List<TransactionRecord> _initialTransactions = [
    TransactionRecord(
      id: '#TRX-20241120-0043',
      timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      items: [
        CartItem(
          product: const Product(
            sku: 'SKU-MB001',
            name: 'Murai Batu Medan',
            category: 'Burung Kicau',
            price: 2450000,
            stock: 3,
            minStock: 5,
            imageUrl: '',
            tags: ['Ring APBN'],
          ),
          quantity: 1,
        ),
        CartItem(
          product: const Product(
            sku: 'SKU-SK009',
            name: 'Sangkar Kayu Jati',
            category: 'Sangkar',
            price: 850000,
            stock: 2,
            minStock: 1,
            imageUrl: '',
          ),
          quantity: 1,
        ),
        CartItem(
          product: const Product(
            sku: 'SKU-FD012',
            name: 'Voer Topsong Ekstra',
            category: 'Pakan & Voer',
            price: 22000,
            stock: 112,
            minStock: 24,
            imageUrl: '',
            tags: ['500g'],
          ),
          quantity: 2,
        ),
      ],
      subtotal: 3344000,
      memberDiscount: 0,
      tax: 0,
      totalAmount: 3344000,
      paymentMethod: PaymentMethod.tunai,
      receivedAmount: 3400000,
      changeAmount: 56000,
      cashierName: 'Bayu Pratama',
      cashierId: '#KSR-02',
    ),
    TransactionRecord(
      id: '#TRX-20241120-0042',
      timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 10)),
      items: [
        CartItem(
          product: const Product(
            sku: 'SKU-CI024',
            name: 'Cucak Ijo Banyuwangi',
            category: 'Burung Kicau',
            price: 1150000,
            stock: 5,
            minStock: 2,
            imageUrl: '',
          ),
          quantity: 1,
        ),
      ],
      subtotal: 1150000,
      memberDiscount: 57500,
      tax: 0,
      totalAmount: 1092500,
      paymentMethod: PaymentMethod.qris,
      receivedAmount: 1092500,
      changeAmount: 0,
      cashierName: 'Bayu Pratama',
      cashierId: '#KSR-02',
    ),
    TransactionRecord(
      id: '#TRX-20241120-0041',
      timestamp: DateTime.now().subtract(const Duration(hours: 4, minutes: 40)),
      items: [
        CartItem(
          product: const Product(
            sku: 'SKU-MD007',
            name: 'Vitamin Burung BioJitu',
            category: 'Obat & Vitamin',
            price: 45000,
            stock: 28,
            minStock: 5,
            imageUrl: '',
          ),
          quantity: 3,
        ),
        CartItem(
          product: const Product(
            sku: 'SKU-FD045',
            name: 'Kroto Segar Bersih',
            category: 'Pakan & Voer',
            price: 35000,
            stock: 2,
            minStock: 10,
            imageUrl: '',
          ),
          quantity: 2,
        ),
      ],
      subtotal: 205000,
      memberDiscount: 0,
      tax: 0,
      totalAmount: 205000,
      paymentMethod: PaymentMethod.transfer,
      receivedAmount: 205000,
      changeAmount: 0,
      cashierName: 'Bayu Pratama',
      cashierId: '#KSR-02',
    ),
  ];

  @override
  TransactionState build() {
    ref.listen(sessionProvider.select((s) => s.shifts), (_, shifts) {
      final existingIds = state.transactions.map((t) => t.id).toSet();
      final saved = shifts
          .expand((s) => s.sales)
          .where((t) => !existingIds.contains(t.id))
          .toList();
      if (saved.isEmpty) return;
      state = state.copyWith(
        transactions: {
          for (final t in state.transactions) t.id: t,
          for (final t in saved) t.id: t,
        }.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
      );
    });
    return TransactionState(
      transactions: [
        ...ref.read(sessionProvider).shifts.expand((s) => s.sales),
        ..._initialTransactions,
      ],
      currentCompletedTransaction: null,
    );
  }

  Future<TransactionRecord> createTransaction({
    required List<CartItem> items,
    required double subtotal,
    required double memberDiscount,
    required double tax,
    required double totalAmount,
    required PaymentMethod paymentMethod,
    required double receivedAmount,
    required double changeAmount,
    required String cashierName,
    required String cashierId,
  }) async {
    final user = ref.read(authProvider.notifier).requireUser();
    final shift = ref.read(sessionProvider.notifier).requireActiveShift();
    if (cashierId != user.cashierCode || cashierName != user.name) {
      throw StateError('Identitas kasir tidak sesuai sesi.');
    }
    final now = ref.read(authClockProvider)().toUtc();
    final idNumber = (state.transactions.length + 44).toString().padLeft(
      4,
      '0',
    );
    final id =
        '#TRX-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-$idNumber';

    final record = TransactionRecord(
      id: id,
      timestamp: now,
      items: items.map((i) => i.copyWith()).toList(),
      subtotal: subtotal,
      memberDiscount: memberDiscount,
      tax: tax,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      receivedAmount: receivedAmount,
      changeAmount: changeAmount,
      cashierName: cashierName,
      cashierId: cashierId,
      shiftId: shift.id,
      isSynced: false,
    );

    if ([
          subtotal,
          memberDiscount,
          tax,
          totalAmount,
          receivedAmount,
          changeAmount,
        ].any((v) => !v.isFinite || v < 0) ||
        (record.items.fold(0.0, (sum, i) => sum + i.subtotal) - subtotal)
                .abs() >=
            .005 ||
        (subtotal - memberDiscount + tax - totalAmount).abs() >= .005 ||
        (receivedAmount - changeAmount - totalAmount).abs() >= .005) {
      throw const AuthException('Nominal pembayaran tidak valid.');
    }
    await ref.read(sessionProvider.notifier).recordSale(record);
    if (!ref.mounted) return record;

    state = state.copyWith(
      transactions: [
        record,
        ...state.transactions.where((t) => t.id != record.id),
      ],
      currentCompletedTransaction: record,
    );

    return record;
  }
}

final transactionProvider =
    NotifierProvider<TransactionNotifier, TransactionState>(
      TransactionNotifier.new,
    );

final visibleTransactionsProvider = Provider<List<TransactionRecord>>((ref) {
  final user = ref.watch(authProvider).currentUser;
  if (user == null) return const [];
  final transactions = ref.watch(transactionProvider).transactions;
  return user.isAdmin
      ? transactions
      : transactions.where((t) => t.cashierId == user.cashierCode).toList();
});

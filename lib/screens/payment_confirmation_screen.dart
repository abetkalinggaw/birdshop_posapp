import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/cart_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';
import 'transaction_success_screen.dart';

class PaymentConfirmationScreen extends ConsumerStatefulWidget {
  final String trxId;
  final PaymentMethod paymentMethod;
  final double receivedAmount;
  final double changeAmount;

  const PaymentConfirmationScreen({
    super.key,
    required this.trxId,
    required this.paymentMethod,
    required this.receivedAmount,
    required this.changeAmount,
  });

  @override
  ConsumerState<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState
    extends ConsumerState<PaymentConfirmationScreen> {
  bool _isProcessing = false;

  Future<void> _handleCommit() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    final cart = ref.read(cartProvider);
    final user = ref.read(authProvider).currentUser;
    if (user == null || cart.items.isEmpty) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masuk kembali dan periksa keranjang Anda.'),
        ),
      );
      return;
    }
    final products = ref.read(inventoryProvider).products;
    for (final item in cart.items) {
      final matching = products.where((p) => p.sku == item.product.sku);
      if (matching.isEmpty || item.quantity > matching.first.stock) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Stok ${item.product.name} berubah. Periksa kembali keranjang.',
            ),
          ),
        );
        return;
      }
    }

    // Commit to transaction provider
    try {
      final transaction = await ref
          .read(transactionProvider.notifier)
          .createTransaction(
            items: cart.items,
            subtotal: cart.subtotal,
            memberDiscount: cart.memberDiscountAmount,
            tax: cart.taxAmount,
            totalAmount: cart.totalPayment,
            paymentMethod: widget.paymentMethod,
            receivedAmount: widget.receivedAmount,
            changeAmount: widget.changeAmount,
            cashierName: user.name,
            cashierId: user.cashierCode,
          );

      // Clear active cart
      if (ref.read(authProvider).currentUser?.id == user.id) {
        ref.invalidate(cartProvider);
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                TransactionSuccessScreen(transaction: transaction),
          ),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AuthException
                  ? e.message
                  : 'Transaksi gagal disimpan. Coba lagi.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: AppColors.surfaceBackground,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverCustomAppBar(
              title: 'Konfirmasi Pembayaran',
              subtitle: widget.trxId,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.badgeAmberBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warningLow),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top,
                            color: AppColors.badgeAmberText,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MENUNGGU KONFIRMASI KASIR',
                                  style: TextStyle(
                                    color: AppColors.badgeAmberText,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.trxId,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Order Summary Card (Ringkasan Pesanan)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ringkasan Pesanan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...cartState.items.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.product.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '@ ${CurrencyFormatter.format(item.product.price)} x ${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(item.subtotal),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const Divider(
                              height: 16,
                              color: AppColors.dividerColor,
                            ),

                            // Cost Details
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Subtotal',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(cartState.subtotal),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                            if (cartState.memberDiscountAmount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Diskon Member',
                                    style: TextStyle(
                                      color: AppColors.accentGreen,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    '- ${CurrencyFormatter.format(cartState.memberDiscountAmount)}',
                                    style: const TextStyle(
                                      color: AppColors.accentGreen,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Tagihan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  CurrencyFormatter.format(
                                    cartState.totalPayment,
                                  ),
                                  style: AppNumbers.total,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Payment Details Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rincian Pembayaran',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Metode',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  widget.paymentMethod.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Uang Diterima',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(
                                    widget.receivedAmount,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kembalian',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(widget.changeAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.accentGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.dividerColor)),
          ),
          child: SafeArea(
            child: PrimaryButton(
              text: 'Konfirmasi & Cetak Struk',
              icon: Icons.check_circle,
              isLoading: _isProcessing,
              onPressed: _handleCommit,
            ),
          ),
        ),
      ),
    );
  }
}

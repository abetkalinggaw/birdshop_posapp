import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/cart_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/cashier_shift_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/quantity_stepper.dart';
import '../widgets/product_artwork.dart';
import 'payment_method_screen.dart';

class CartCheckoutScreen extends ConsumerWidget {
  const CartCheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final session = ref.watch(sessionProvider);
    final activeShift = session.activeShift;
    final shiftReady =
        activeShift != null &&
        !ref.read(sessionProvider.notifier).isPreviousDay(activeShift);

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Unified SliverCustomAppBar with Back Button
          SliverCustomAppBar(
            title: 'Keranjang Belanja',
            subtitle: cartState.items.isNotEmpty
                ? '${cartState.totalItemCount} Produk Dipilih'
                : 'Kosong',
            actions: [
              if (cartState.items.isNotEmpty)
                TopBarActionButton(
                  icon: Icons.delete_sweep_outlined,
                  tooltip: 'Kosongkan Keranjang',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Kosongkan Keranjang?'),
                        content: const Text(
                          'Semua item di keranjang belanja akan dihapus.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () {
                              ref.read(cartProvider.notifier).clearCart();
                              Navigator.of(ctx).pop();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Hapus',
                              style: TextStyle(color: AppColors.alertCritical),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),

          // Empty state or Items List
          if (cartState.items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.remove_shopping_cart_outlined,
                      size: 64,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Keranjang Belanja Kosong',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pilih produk dari katalog Kasir POS',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: PrimaryButton(
                        text: 'Kembali ke Kasir',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Cart Items List
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverList.separated(
                itemCount: cartState.items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = cartState.items[index];
                  final product = item.product;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.dividerColor),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceBackground,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.dividerColor,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: ProductArtwork(
                                  imagePath: product.imageUrl,
                                  category: product.category,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'SKU: ${product.sku}',
                                      style: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    if (product.tags.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        product.tags.join(' · '),
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.alertCritical,
                                  size: 20,
                                ),
                                onPressed: () {
                                  ref
                                      .read(cartProvider.notifier)
                                      .removeItem(product.sku);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(
                            height: 1,
                            color: AppColors.dividerColor,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga: ${CurrencyFormatter.format(product.price)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: AppColors.primaryGreen,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              QuantityStepper(
                                value: item.quantity,
                                minValue: 1,
                                maxValue: product.stock,
                                onChanged: (newQty) {
                                  ref
                                      .read(cartProvider.notifier)
                                      .updateQuantity(product.sku, newQty);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Order Calculations Breakdown Card
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtotal Produk',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(cartState.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      if (cartState.memberDiscountPercentage > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Diskon Member (${cartState.memberDiscountPercentage.toInt()}%)',
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '- ${CurrencyFormatter.format(cartState.memberDiscountAmount)}',
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'PPN (11%)',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(cartState.taxAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(
                          height: 1,
                          color: AppColors.dividerColor,
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total pembayaran',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyFormatter.format(cartState.totalPayment),
                            style: AppNumbers.price.copyWith(fontSize: 24),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: cartState.items.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: AppColors.dividerColor),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total tagihan',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(cartState.totalPayment),
                          style: AppNumbers.price.copyWith(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (session.error != null) ...[
                      Text(
                        session.error!,
                        style: const TextStyle(color: AppColors.alertCritical),
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.read(sessionProvider.notifier).load(),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                    PrimaryButton(
                      text: shiftReady
                          ? 'Pilih pembayaran'
                          : activeShift != null
                          ? 'Tutup Shift Sebelumnya'
                          : 'Buka Shift untuk Membayar',
                      icon: Icons.payment,
                      isLoading: session.loading || session.saving,
                      onPressed: session.error != null
                          ? null
                          : !shiftReady
                          ? () => showCashierShiftSheet(
                              context,
                              closing: activeShift,
                            )
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PaymentMethodScreen(),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_controls.dart';
import '../widgets/primary_button.dart';
import 'receipt_print_screen.dart';

class TransactionSuccessScreen extends StatelessWidget {
  final TransactionRecord transaction;

  const TransactionSuccessScreen({super.key, required this.transaction});

  void _showThermalReceipt(BuildContext context) {
    openReceiptPrinting(context, transaction);
  }

  @override
  Widget build(BuildContext context) {
    DateFormat dateFormat;
    try {
      dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    } catch (_) {
      dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverCustomAppBar(
            title: 'Transaksi Selesai',
            subtitle: 'Struk ${transaction.id}',
            actions: [
              TopBarActionButton(
                icon: Icons.add_shopping_cart,
                tooltip: 'Transaksi Baru',
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 60),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Success Hero Icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.badgeGreenBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: AppColors.accentGreen,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Transaksi Berhasil!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Struk pembayaran telah tercatat di sistem',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Receipt Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Nomor Struk',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                transaction.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Waktu Transaksi',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                dateFormat.format(transaction.timestamp),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Kasir',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${transaction.cashierName} (${transaction.cashierId})',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Metode Pembayaran',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              AppBadge(
                                label: transaction.paymentMethod.code,
                                tone: AppBadgeTone.positive,
                              ),
                            ],
                          ),
                          const Divider(
                            height: 20,
                            color: AppColors.dividerColor,
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Pembayaran',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                CurrencyFormatter.format(
                                  transaction.totalAmount,
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

                  // Collapsible Item Accordion
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      shape: const Border(),
                      collapsedShape: const Border(),
                      backgroundColor: AppColors.surfaceCard,
                      collapsedBackgroundColor: AppColors.surfaceCard,
                      iconColor: AppColors.primaryGreen,
                      collapsedIconColor: AppColors.primaryGreen,
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      title: Text(
                        'Rincian Item (${transaction.items.length} Macam)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      children: [
                        ...transaction.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${item.quantity} × ${CurrencyFormatter.format(item.product.price)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  CurrencyFormatter.format(item.subtotal),
                                  style: AppNumbers.price.copyWith(
                                    fontSize: 16,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: AppButtonStyles.tonal,
                      label: const Text('Cetak Struk Thermal'),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      onPressed: () => _showThermalReceipt(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    text: 'Transaksi Baru Kasir',
                    icon: Icons.add_shopping_cart,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

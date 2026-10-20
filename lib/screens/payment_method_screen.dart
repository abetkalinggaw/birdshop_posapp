import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction.dart';
import '../providers/cart_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/app_controls.dart';
import 'payment_confirmation_screen.dart';

class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.tunai;
  late TextEditingController _cashController;
  double _receivedAmount = 0;
  late String _generatedTrxId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _generatedTrxId =
        '#TRX-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-0043';
    _cashController = TextEditingController();
  }

  @override
  void dispose() {
    _cashController.dispose();
    super.dispose();
  }

  List<double> _getQuickNominals(double total) {
    final list = <double>[total]; // Uang Pas
    // Next rounded up increments (e.g. 50k, 100k, 500k)
    if (total < 100000) {
      list.add(100000);
      list.add(200000);
    } else if (total < 1000000) {
      final next500k = ((total / 500000).ceil() * 500000).toDouble();
      if (!list.contains(next500k)) list.add(next500k);
      list.add(next500k + 100000);
      list.add(next500k + 500000);
    } else {
      final next100k = ((total / 100000).ceil() * 100000).toDouble();
      if (!list.contains(next100k)) list.add(next100k);
      final next500k = ((total / 500000).ceil() * 500000).toDouble();
      if (!list.contains(next500k)) list.add(next500k);
      final next1M = ((total / 1000000).ceil() * 1000000).toDouble();
      if (!list.contains(next1M)) list.add(next1M);
    }
    return list.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final totalPayment = cartState.totalPayment;
    final quickNominals = _getQuickNominals(totalPayment);

    final changeAmount = _receivedAmount >= totalPayment
        ? _receivedAmount - totalPayment
        : 0.0;
    final isCashSufficient =
        _selectedMethod != PaymentMethod.tunai ||
        _receivedAmount >= totalPayment;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverCustomAppBar(
            title: 'Metode Pembayaran',
            subtitle: 'Pilih Cara Bayar Pelanggan',
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total tagihan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCCEADD),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(totalPayment),
                            style: AppNumbers.total.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _generatedTrxId,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFCCEADD),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Method Selector
                  const Text(
                    'Pilih Metode Pembayaran',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: PaymentMethod.values.map((method) {
                      final isSelected = method == _selectedMethod;
                      IconData icon;
                      switch (method) {
                        case PaymentMethod.tunai:
                          icon = Icons.payments_outlined;
                          break;
                        case PaymentMethod.qris:
                          icon = Icons.qr_code_2;
                          break;
                        case PaymentMethod.transfer:
                          icon = Icons.account_balance_outlined;
                          break;
                      }

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedMethod = method;
                                if (method != PaymentMethod.tunai) {
                                  _receivedAmount = totalPayment;
                                  _cashController.text = totalPayment
                                      .toStringAsFixed(0);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.actionSurface
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : AppColors.dividerColor,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    icon,
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : AppColors.textSecondary,
                                    size: 24,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    method.code,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Method Specific Content
                  if (_selectedMethod == PaymentMethod.tunai) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.point_of_sale,
                                  size: 20,
                                  color: AppColors.primaryGreen,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Kalkulator Uang Tunai',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Uang Diterima (Rp)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _cashController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: const InputDecoration(
                                prefixText: 'Rp ',
                                prefixStyle: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                                hintText: '0',
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _receivedAmount = double.tryParse(val) ?? 0;
                                });
                              },
                            ),

                            const SizedBox(height: 12),

                            // Quick Nominals
                            const Text(
                              'Pilihan Cepat Nominal:',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: quickNominals.map((nom) {
                                final isUangPas = nom == totalPayment;
                                return AppFilterChip(
                                  label: isUangPas
                                      ? 'Uang pas'
                                      : CurrencyFormatter.format(nom),
                                  selected: _receivedAmount == nom,
                                  onTap: () => setState(() {
                                    _receivedAmount = nom;
                                    _cashController.text = nom.toStringAsFixed(
                                      0,
                                    );
                                  }),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),
                            const Divider(
                              height: 1,
                              color: AppColors.dividerColor,
                            ),
                            const SizedBox(height: 14),

                            // Kembalian
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kembalian:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(changeAmount),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _receivedAmount < totalPayment
                                        ? AppColors.alertCritical
                                        : AppColors.primaryGreen,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_receivedAmount > 0 &&
                                _receivedAmount < totalPayment) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Uang kurang ${CurrencyFormatter.format(totalPayment - _receivedAmount)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.alertCritical,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ] else if (_selectedMethod == PaymentMethod.qris) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Center(
                          child: Column(
                            children: [
                              const Text(
                                'Tunjukkan QRIS Dinamis ke Pembeli',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.dividerColor,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code_2,
                                      size: 160,
                                      color: AppColors.textPrimary,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'QRIS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nominal: ${CurrencyFormatter.format(totalPayment)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Terhubung langsung dengan BCA, Mandiri, GoPay, OVO, ShopeePay',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Rekening Tujuan Transfer',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.dividerColor,
                                ),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    color: AppColors.primaryGreen,
                                  ),
                                  SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'BCA Cab. Pramuka',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        '542-019-8821',
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'a.n. EX-SHA BIRD SHOP',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

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
            text: 'Bayar Sekarang',
            icon: Icons.check_circle_outline,
            onPressed: isCashSufficient
                ? () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaymentConfirmationScreen(
                          trxId: _generatedTrxId,
                          paymentMethod: _selectedMethod,
                          receivedAmount: _selectedMethod == PaymentMethod.tunai
                              ? _receivedAmount
                              : totalPayment,
                          changeAmount: _selectedMethod == PaymentMethod.tunai
                              ? changeAmount
                              : 0.0,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

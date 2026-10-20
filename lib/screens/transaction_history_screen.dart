import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_controls.dart';
import 'receipt_print_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

enum _TransactionViewMode { list, grid }

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedMethodFilter = 'Semua';
  String _sortBy = 'Terbaru'; // 'Terbaru', 'Nominal Tertinggi'
  _TransactionViewMode _viewMode = _TransactionViewMode.list;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _printReceipt(TransactionRecord tx) {
    openReceiptPrinting(context, tx);
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Riwayat Transaksi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_selectedMethodFilter != 'Semua' ||
                          _sortBy != 'Terbaru')
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedMethodFilter = 'Semua';
                              _sortBy = 'Terbaru';
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: AppColors.alertCritical,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Metode Pembayaran',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Semua', 'Tunai', 'QRIS', 'Transfer'].map((m) {
                      final isSelected = _selectedMethodFilter == m;
                      return AppFilterChip(
                        label: m,
                        selected: isSelected,
                        onTap: () {
                          setModalState(() => _selectedMethodFilter = m);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Urutkan Berdasarkan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Terbaru', 'Nominal Tertinggi'].map((s) {
                      final isSelected = _sortBy == s;
                      return AppFilterChip(
                        label: s,
                        selected: isSelected,
                        onTap: () {
                          setModalState(() => _sortBy = s);
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Terapkan Filter',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(visibleTransactionsProvider);
    final compactDateFormat = DateFormat('dd/MM HH:mm');

    // Filter & Sort list
    var filteredList = transactions.where((t) {
      final query = _searchController.text.toLowerCase();
      final matchQuery =
          query.isEmpty ||
          t.id.toLowerCase().contains(query) ||
          t.cashierName.toLowerCase().contains(query) ||
          t.items.any((i) => i.product.name.toLowerCase().contains(query));

      if (!matchQuery) return false;

      if (_selectedMethodFilter == 'Tunai') {
        return t.paymentMethod == PaymentMethod.tunai;
      }
      if (_selectedMethodFilter == 'QRIS') {
        return t.paymentMethod == PaymentMethod.qris;
      }
      if (_selectedMethodFilter == 'Transfer') {
        return t.paymentMethod == PaymentMethod.transfer;
      }
      return true;
    }).toList();

    if (_sortBy == 'Nominal Tertinggi') {
      filteredList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    } else {
      filteredList.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    // Calculate composition
    double cashSum = 0;
    double qrisSum = 0;
    double transferSum = 0;
    final now = DateTime.now();
    for (final t in transactions) {
      final isToday =
          t.timestamp.year == now.year &&
          t.timestamp.month == now.month &&
          t.timestamp.day == now.day;
      if (!isToday) continue;

      if (t.paymentMethod == PaymentMethod.tunai) cashSum += t.totalAmount;
      if (t.paymentMethod == PaymentMethod.qris) qrisSum += t.totalAmount;
      if (t.paymentMethod == PaymentMethod.transfer) {
        transferSum += t.totalAmount;
      }
    }
    final totalSum = cashSum + qrisSum + transferSum;
    final cashPct = totalSum > 0 ? (cashSum / totalSum * 100).toInt() : 0;
    final qrisPct = totalSum > 0 ? (qrisSum / totalSum * 100).toInt() : 0;
    final transferPct = totalSum > 0
        ? (transferSum / totalSum * 100).toInt()
        : 0;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Unified Top Bar with integrated search pill and right actions
          SliverCustomAppBar.search(
            searchController: _searchController,
            searchHint: 'Cari no. struk / kasir / item...',
            onSearchChanged: (val) => setState(() {}),
            onSearchClear: () => setState(() {}),
            onFilterTap: _openFilterBottomSheet,
            hasActiveFilter:
                _selectedMethodFilter != 'Semua' || _sortBy != 'Terbaru',
            actions: [
              TopBarActionButton(
                icon: Icons.file_download_outlined,
                tooltip: 'Ekspor Laporan CSV',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Laporan transaksi berhasil diekspor (.csv)',
                      ),
                      backgroundColor: AppColors.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),

          // Daily Summary Composition Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Komposisi pembayaran hari ini',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(totalSum),
                      style: AppNumbers.total,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Multi-colored Composition Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 8,
                      child: Row(
                        children: [
                          if (cashPct > 0)
                            Expanded(
                              flex: cashPct,
                              child: Container(color: AppColors.primaryGreen),
                            ),
                          if (qrisPct > 0)
                            Expanded(
                              flex: qrisPct,
                              child: Container(color: AppColors.accentGreen),
                            ),
                          if (transferPct > 0)
                            Expanded(
                              flex: transferPct,
                              child: Container(color: const Color(0xFF6366F1)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LegendItem(
                        color: AppColors.primaryGreen,
                        label: 'Tunai ($cashPct%)',
                      ),
                      _LegendItem(
                        color: AppColors.accentGreen,
                        label: 'QRIS ($qrisPct%)',
                      ),
                      _LegendItem(
                        color: const Color(0xFF6366F1),
                        label: 'Transfer ($transferPct%)',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(height: 1, color: AppColors.dividerColor),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${filteredList.length} transaksi',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SegmentedButton<_TransactionViewMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: _TransactionViewMode.list,
                        icon: Icon(Icons.view_agenda_outlined),
                        tooltip: 'Tampilan daftar',
                      ),
                      ButtonSegment(
                        value: _TransactionViewMode.grid,
                        icon: Icon(Icons.grid_view_rounded),
                        tooltip: 'Tampilan kisi',
                      ),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (selection) {
                      setState(() => _viewMode = selection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Transactions in the selected view
          if (filteredList.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tidak ada transaksi yang cocok dengan filter',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_viewMode == _TransactionViewMode.list)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList.separated(
                itemCount: filteredList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildTransactionListTile(
                    filteredList[index],
                    compactDateFormat,
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width >= 1000
                      ? 4
                      : MediaQuery.sizeOf(context).width >= 700
                      ? 3
                      : 2,
                  mainAxisExtent:
                      210 +
                      (MediaQuery.textScalerOf(context).scale(1) - 1) * 130,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildTransactionGridCard(
                    filteredList[index],
                    compactDateFormat,
                  ),
                  childCount: filteredList.length,
                ),
              ),
            ),

          // Bottom padding for bottom navigation
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildTransactionListTile(
    TransactionRecord tx,
    DateFormat dateFormat,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTransactionDetails(tx),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      CurrencyFormatter.format(tx.totalAmount),
                      style: AppNumbers.price,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tx.id,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dateFormat.format(tx.timestamp)} · ${_paymentMethodName(tx.paymentMethod)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${tx.items.length} produk',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionGridCard(
    TransactionRecord tx,
    DateFormat dateFormat,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTransactionDetails(tx),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _paymentMethodIcon(tx.paymentMethod),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _paymentMethodName(tx.paymentMethod),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                tx.id,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  CurrencyFormatter.format(tx.totalAmount),
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${dateFormat.format(tx.timestamp)}  ·  ${tx.items.length} produk',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              const Divider(height: 1, color: AppColors.dividerColor),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    'Lihat detail',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primaryGreen,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _paymentMethodName(PaymentMethod method) => switch (method) {
    PaymentMethod.tunai => 'Tunai',
    PaymentMethod.qris => 'QRIS',
    PaymentMethod.transfer => 'Transfer',
  };

  IconData _paymentMethodIcon(PaymentMethod method) => switch (method) {
    PaymentMethod.tunai => Icons.payments_outlined,
    PaymentMethod.qris => Icons.qr_code_2_rounded,
    PaymentMethod.transfer => Icons.account_balance_outlined,
  };

  void _openTransactionDetails(TransactionRecord tx) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Detail transaksi',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(tx.id, style: Theme.of(sheetContext).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Text(
                  CurrencyFormatter.format(tx.totalAmount),
                  style: Theme.of(sheetContext).textTheme.headlineMedium
                      ?.copyWith(color: AppColors.primaryGreen),
                ),
                const SizedBox(height: 6),
                Text(
                  '${dateFormat.format(tx.timestamp)}  ·  ${_paymentMethodName(tx.paymentMethod)}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: AppColors.dividerColor),
                ),
                Text(
                  'Item (${tx.items.length})',
                  style: Theme.of(sheetContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                ...tx.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.product.name}  ×${item.quantity}',
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          CurrencyFormatter.format(item.subtotal),
                          style: Theme.of(sheetContext).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: AppColors.dividerColor),
                ),
                _detailAmountRow('Subtotal', tx.subtotal),
                if (tx.memberDiscount > 0)
                  _detailAmountRow('Diskon member', -tx.memberDiscount),
                if (tx.tax > 0) _detailAmountRow('Pajak', tx.tax),
                const SizedBox(height: 8),
                _detailAmountRow('Total', tx.totalAmount, emphasized: true),
                const SizedBox(height: 14),
                Text(
                  'Kasir: ${tx.cashierName}',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                if (tx.shiftId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Shift: ${tx.shiftId}',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _printReceipt(tx);
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Cetak struk'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailAmountRow(
    String label,
    double amount, {
    bool emphasized = false,
  }) {
    final style = TextStyle(
      color: emphasized ? AppColors.textPrimary : AppColors.textSecondary,
      fontSize: emphasized ? 14 : 12,
      fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(CurrencyFormatter.format(amount), style: style),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

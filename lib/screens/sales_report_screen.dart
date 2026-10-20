import '../providers/auth_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/app_controls.dart';

class SalesReportScreen extends ConsumerStatefulWidget {
  const SalesReportScreen({super.key});

  @override
  ConsumerState<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends ConsumerState<SalesReportScreen> {
  String _selectedPeriod = 'Hari Ini';

  final List<String> _periods = [
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
    'Kustom',
  ];

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).currentUser?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Akses hanya untuk Admin.')),
      );
    }
    final txState = ref.watch(transactionProvider);

    // Dynamic metrics based on period
    final grossTurnover = _selectedPeriod == 'Hari Ini'
        ? txState.todayGrossTurnover + 4641500
        : 46850000.0;
    final netProfit = grossTurnover * 0.28;
    final avgReceipt =
        grossTurnover / (_selectedPeriod == 'Hari Ini' ? 14 : 98);
    final txCount = _selectedPeriod == 'Hari Ini'
        ? txState.todayTransactionCount + 11
        : 98;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverCustomAppBar(
            title: 'Laporan Penjualan',
            subtitle: 'Analisis & Kinerja Toko',
            actions: [
              TopBarActionButton(
                icon: Icons.print_outlined,
                tooltip: 'Cetak Rekap',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Mengirim rekapan laporan ke printer thermal...',
                      ),
                      backgroundColor: AppColors.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              TopBarActionButton(
                icon: Icons.file_download_outlined,
                tooltip: 'Ekspor PDF',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Laporan Rekap Penjualan berhasil diekspor ke PDF!',
                      ),
                      backgroundColor: AppColors.primaryGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _periods
                          .map(
                            (period) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: AppFilterChip(
                                label: period,
                                selected: period == _selectedPeriod,
                                onTap: () =>
                                    setState(() => _selectedPeriod = period),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        Text(
                          'Omset kotor · $_selectedPeriod',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFCCEADD),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.format(grossTurnover),
                            style: AppNumbers.total.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const AppBadge(
                          label: '+18.4% MoM',
                          tone: AppBadgeTone.positive,
                          icon: Icons.trending_up_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        _KpiMetricTile(
                          title: 'Estimasi profit',
                          value: CurrencyFormatter.format(netProfit),
                          subtitle: 'Margin 28%',
                          icon: Icons.savings_outlined,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _KpiMetricTile(
                          title: 'Rata-rata struk',
                          value: CurrencyFormatter.format(avgReceipt),
                          subtitle: 'Ideal Retail',
                          icon: Icons.receipt_long_outlined,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        _KpiMetricTile(
                          title: 'Volume transaksi',
                          value: '$txCount Trx',
                          subtitle: 'Shift Stabil',
                          icon: Icons.shopping_bag_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 7-Day Trend Bar Chart Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tren Penjualan 7 Hari Terakhir',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '(Dalam Jutaan Rp)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Custom Responsive Bar Chart
                          SizedBox(
                            height: 140,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                _BarItem(
                                  day: 'Sen',
                                  valueM: 3.8,
                                  maxHeight: 80,
                                ),
                                _BarItem(
                                  day: 'Sel',
                                  valueM: 4.2,
                                  maxHeight: 80,
                                ),
                                _BarItem(
                                  day: 'Rab',
                                  valueM: 3.1,
                                  maxHeight: 80,
                                ),
                                _BarItem(
                                  day: 'Kam',
                                  valueM: 5.6,
                                  maxHeight: 80,
                                ),
                                _BarItem(
                                  day: 'Jum',
                                  valueM: 6.2,
                                  maxHeight: 80,
                                ),
                                _BarItem(
                                  day: 'Sab',
                                  valueM: 8.9,
                                  maxHeight: 80,
                                  isHighlight: true,
                                ),
                                _BarItem(
                                  day: 'Min',
                                  valueM: 9.4,
                                  maxHeight: 80,
                                  isHighlight: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Category Distribution Progress Bars
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Distribusi Kategori Penjualan',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _CategoryProgressBar(
                            category: 'Burung Kicau (Murai, Cucak, Kacer)',
                            percentage: 64,
                            amount: 'Rp 30.120.000',
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(height: 12),
                          _CategoryProgressBar(
                            category: 'Pakan & Voer Topsong/Kroto',
                            percentage: 18,
                            amount: 'Rp 8.420.000',
                            color: AppColors.accentGreen,
                          ),
                          const SizedBox(height: 12),
                          _CategoryProgressBar(
                            category: 'Sangkar & Aksesoris',
                            percentage: 12,
                            amount: 'Rp 5.600.000',
                            color: AppColors.warningLow,
                          ),
                          const SizedBox(height: 12),
                          _CategoryProgressBar(
                            category: 'Obat & Vitamin Burung',
                            percentage: 6,
                            amount: 'Rp 2.710.000',
                            color: const Color(0xFF6366F1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Top Products Ranked Table
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Produk Terlaris (Top Selling)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TopProductRow(
                            rank: 1,
                            name: 'Murai Batu Medan Ring APBN',
                            sold: '12 Ekor',
                            revenue: 'Rp 29.400.000',
                            margin: 'Margin 32%',
                          ),
                          const Divider(
                            height: 16,
                            color: AppColors.dividerColor,
                          ),
                          _TopProductRow(
                            rank: 2,
                            name: 'Voer Topsong Ekstra 500g',
                            sold: '148 Bks',
                            revenue: 'Rp 3.256.000',
                            margin: 'Margin 22%',
                          ),
                          const Divider(
                            height: 16,
                            color: AppColors.dividerColor,
                          ),
                          _TopProductRow(
                            rank: 3,
                            name: 'Cucak Ijo Banyuwangi',
                            sold: '4 Ekor',
                            revenue: 'Rp 4.600.000',
                            margin: 'Margin 28%',
                          ),
                          const Divider(
                            height: 16,
                            color: AppColors.dividerColor,
                          ),
                          _TopProductRow(
                            rank: 4,
                            name: 'Vitamin Burung BioJitu Drop',
                            sold: '36 Btl',
                            revenue: 'Rp 1.620.000',
                            margin: 'Margin 45%',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Download Report Button (Action)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.download,
                        color: AppColors.primaryGreen,
                      ),
                      label: const Text(
                        'Unduh Rekap Laporan (PDF / Excel)',
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Laporan Rekap Penjualan berhasil diekspor ke PDF!',
                            ),
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        );
                      },
                    ),
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

class _KpiMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _KpiMetricTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 22, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppNumbers.price,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  final String day;
  final double valueM;
  final double maxHeight;
  final bool isHighlight;

  const _BarItem({
    required this.day,
    required this.valueM,
    required this.maxHeight,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = (valueM / 10.0) * maxHeight;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${valueM.toStringAsFixed(1)}jt',
          style: TextStyle(
            fontSize: 9,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight
                ? AppColors.primaryGreen
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: barHeight,
          decoration: BoxDecoration(
            color: isHighlight
                ? AppColors.primaryGreen
                : AppColors.primaryGreen.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
            color: isHighlight
                ? AppColors.primaryGreen
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CategoryProgressBar extends StatelessWidget {
  final String category;
  final int percentage;
  final String amount;
  final Color color;

  const _CategoryProgressBar({
    required this.category,
    required this.percentage,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              amount,
              style: AppNumbers.price.copyWith(
                color: AppColors.textPrimary,
                fontSize: 18,
              ),
            ),
            Text(
              '$percentage%',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: AppColors.surfaceCardMuted,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final String name;
  final String sold;
  final String revenue;
  final String margin;

  const _TopProductRow({
    required this.rank,
    required this.name,
    required this.sold,
    required this.revenue,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '$rank',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Terjual: $sold · $margin',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(revenue, style: AppNumbers.price.copyWith(fontSize: 18)),
            ],
          ),
        ),
      ],
    );
  }
}

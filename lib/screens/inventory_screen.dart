import '../providers/auth_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/inventory_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/app_controls.dart';
import '../widgets/product_manage_modal.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<String> _stockFilters = [
    'Semua',
    'Stok Aman',
    'Stok Kritis',
    'Burung Kicau',
    'Pakan & Voer',
    'Sangkar',
    'Obat & Vitamin',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddProductModal() {
    AddProductModal.show(context);
  }

  void _openStockFilterSheet() {
    final inventoryState = ref.read(inventoryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                    'Filter Inventaris & Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (inventoryState.selectedCategory != 'Semua')
                    TextButton(
                      onPressed: () {
                        ref
                            .read(inventoryProvider.notifier)
                            .setCategory('Semua');
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stockFilters.map((filter) {
                  final isSelected = filter == inventoryState.selectedCategory;
                  return AppFilterChip(
                    label: filter,
                    selected: isSelected,
                    onTap: () {
                      ref.read(inventoryProvider.notifier).setCategory(filter);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authProvider).currentUser?.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Akses hanya untuk Admin.')),
      );
    }
    final inventoryState = ref.watch(inventoryProvider);
    final sessionState = ref.watch(sessionProvider);
    final timeFormat = DateFormat('HH:mm:ss');
    final products = inventoryState.filteredProducts;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Unified Top Bar with integrated search pill and actions
          SliverCustomAppBar.search(
            searchController: _searchController,
            searchHint: 'Cari SKU / nama burung / pakan...',
            onSearchChanged: (val) {
              ref.read(inventoryProvider.notifier).setSearchQuery(val);
            },
            onSearchClear: () {
              ref.read(inventoryProvider.notifier).setSearchQuery('');
            },
            onFilterTap: _openStockFilterSheet,
            hasActiveFilter: inventoryState.selectedCategory != 'Semua',
            actions: [
              TopBarActionButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Muat Ulang Inventaris',
                onTap: sessionState.saving
                    ? () {}
                    : () {
                        ref.read(inventoryProvider.notifier).refreshInventory();
                      },
              ),
              TopBarActionButton(
                icon: Icons.add_box_outlined,
                tooltip: 'Tambah Produk',
                onTap: _showAddProductModal,
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nilai aset inventaris',
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
                      CurrencyFormatter.format(inventoryState.totalAssetValue),
                      style: AppNumbers.total,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${inventoryState.totalActiveSku}',
                              style: AppNumbers.metric,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'SKU aktif',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 44,
                        color: AppColors.dividerColor,
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${inventoryState.criticalStockCount}',
                              style: AppNumbers.metric.copyWith(
                                color: inventoryState.criticalStockCount > 0
                                    ? AppColors.badgeRedText
                                    : AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Perlu restok',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              height: 60,
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _stockFilters.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = _stockFilters[index];
                  return AppFilterChip(
                    label: filter,
                    selected: filter == inventoryState.selectedCategory,
                    onTap: () => ref
                        .read(inventoryProvider.notifier)
                        .setCategory(filter),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: Divider(height: 1, color: AppColors.dividerColor),
          ),

          // Product List in Slivers
          if (products.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tidak ada produk yang cocok dengan filter',
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
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList.separated(
                itemCount: products.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    onManagePressed: () {
                      EditProductModal.show(context, product: product);
                    },
                  );
                },
              ),
            ),

          // Bottom Sync Info micro-bar & padding for bottom navigation
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: AppColors.accentGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Data lokal · Dimuat ${timeFormat.format(inventoryState.lastLoaded)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${products.length} SKU Ditampilkan',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/currency_formatter.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/product_artwork.dart';
import '../widgets/app_controls.dart';
import 'cart_checkout_screen.dart';

class PosCashierScreen extends ConsumerStatefulWidget {
  const PosCashierScreen({super.key});

  @override
  ConsumerState<PosCashierScreen> createState() => _PosCashierScreenState();
}

class _PosCashierScreenState extends ConsumerState<PosCashierScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String _selectedCategory = 'Semua';
  String _selectedStockFilter = 'Semua'; // 'Semua', 'Tersedia', 'Kritis'
  String _selectedSort = 'default'; // 'default', 'name_asc', 'price_asc', 'price_desc', 'stock_desc'

  final List<String> _categories = [
    'Semua',
    'Burung Kicau',
    'Pakan & Voer',
    'Sangkar',
    'Obat & Vitamin',
    'Aksesoris',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasCustomFilter =>
      _selectedCategory != 'Semua' ||
      _selectedStockFilter != 'Semua' ||
      _selectedSort != 'default';

  List<Product> _getFilteredAndSortedProducts(List<Product> rawProducts) {
    final query = _searchController.text.trim().toLowerCase();

    var list = rawProducts.where((p) {
      final matchesSearch =
          query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query) ||
          p.tags.any((t) => t.toLowerCase().contains(query));

      if (!matchesSearch) return false;

      if (_selectedCategory != 'Semua' && p.category != _selectedCategory) {
        return false;
      }

      if (_selectedStockFilter == 'Tersedia' && p.stock <= 0) {
        return false;
      } else if (_selectedStockFilter == 'Kritis' && p.stock > p.minStock) {
        return false;
      }

      return true;
    }).toList();

    switch (_selectedSort) {
      case 'name_asc':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'stock_desc':
        list.sort((a, b) => b.stock.compareTo(a.stock));
        break;
      default:
        break;
    }

    return list;
  }

  void _openFilterBottomSheet(BuildContext context) {
    String tempCategory = _selectedCategory;
    String tempStockFilter = _selectedStockFilter;
    String tempSort = _selectedSort;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Modal Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    child: Column(
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
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                size: 20,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Filter & Urutan Katalog',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Sesuaikan tampilan produk di kasir',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(ctx).pop(),
                              tooltip: 'Tutup',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.dividerColor),

                  // Options Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Kategori
                          const Text(
                            'Kategori Produk',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _categories.map((cat) {
                              final isSelected = cat == tempCategory;
                              return AppFilterChip(
                                label: cat,
                                selected: isSelected,
                                onTap: () =>
                                    setModalState(() => tempCategory = cat),
                              );
                            }).toList(),
                          ),

                          const SizedBox(height: 20),

                          // 2. Status Stok
                          const Text(
                            'Ketersediaan Stok',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildChipOption(
                                label: 'Semua Stok',
                                isSelected: tempStockFilter == 'Semua',
                                onSelected: () => setModalState(
                                  () => tempStockFilter = 'Semua',
                                ),
                              ),
                              _buildChipOption(
                                label: 'Tersedia Saja',
                                isSelected: tempStockFilter == 'Tersedia',
                                onSelected: () => setModalState(
                                  () => tempStockFilter = 'Tersedia',
                                ),
                              ),
                              _buildChipOption(
                                label: 'Stok Kritis / Habis',
                                isSelected: tempStockFilter == 'Kritis',
                                onSelected: () => setModalState(
                                  () => tempStockFilter = 'Kritis',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 3. Urutkan Menurut
                          const Text(
                            'Urutkan Menurut',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildChipOption(
                                label: 'Rekomendasi Default',
                                isSelected: tempSort == 'default',
                                onSelected: () =>
                                    setModalState(() => tempSort = 'default'),
                              ),
                              _buildChipOption(
                                label: 'Nama (A - Z)',
                                isSelected: tempSort == 'name_asc',
                                onSelected: () =>
                                    setModalState(() => tempSort = 'name_asc'),
                              ),
                              _buildChipOption(
                                label: 'Harga: Termurah',
                                isSelected: tempSort == 'price_asc',
                                onSelected: () =>
                                    setModalState(() => tempSort = 'price_asc'),
                              ),
                              _buildChipOption(
                                label: 'Harga: Tertinggi',
                                isSelected: tempSort == 'price_desc',
                                onSelected: () => setModalState(
                                  () => tempSort = 'price_desc',
                                ),
                              ),
                              _buildChipOption(
                                label: 'Stok Terbanyak',
                                isSelected: tempSort == 'stock_desc',
                                onSelected: () => setModalState(
                                  () => tempSort = 'stock_desc',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.dividerColor),

                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              side: const BorderSide(
                                color: AppColors.dividerColor,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'Semua';
                                _selectedStockFilter = 'Semua';
                                _selectedSort = 'default';
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedCategory = tempCategory;
                                _selectedStockFilter = tempStockFilter;
                                _selectedSort = tempSort;
                              });
                              Navigator.of(ctx).pop();
                            },
                            child: const Text(
                              'Terapkan Filter',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChipOption({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return AppFilterChip(label: label, selected: isSelected, onTap: onSelected);
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);
    final cartState = ref.watch(cartProvider);
    final sessionState = ref.watch(sessionProvider);

    final filteredProducts = _getFilteredAndSortedProducts(
      inventoryState.products,
    );

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Floating Top Bar with Integrated Searchbar & Actions
              SliverCustomAppBar.search(
                searchController: _searchController,
                searchHint: 'Cari produk / SKU...',
                onSearchChanged: (val) => setState(() {}),
                onSearchClear: () => setState(() {}),
                onFilterTap: () => _openFilterBottomSheet(context),
                hasActiveFilter: _hasCustomFilter,
                actions: const [],
              ),

              // 2. Store Info Strip & Category Filter Pills
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surfaceBackground,
                  child: Column(
                    children: [
                      // Branch & Status Micro-Bar (ScreenContextBar - POS screen only)
                      ScreenContextBar(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                        leading: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sessionState.shopName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sessionState.shopBranch,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: AppBadge(
                          label: sessionState.isOnline ? 'Online' : 'Offline',
                          tone: sessionState.isOnline
                              ? AppBadgeTone.positive
                              : AppBadgeTone.warning,
                        ),
                      ),

                      // Shared category controls keep selection consistent with filters.
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = _categories[index];
                            return AppFilterChip(
                              label: category,
                              selected: category == _selectedCategory,
                              onTap: () =>
                                  setState(() => _selectedCategory = category),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.dividerColor),
                    ],
                  ),
                ),
              ),

              // 3. Catalog Grid / Empty State
              filteredProducts.isEmpty
                  ? SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 54,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Produk tidak ditemukan',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Coba ganti kata kunci atau atur ulang filter pencarian',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_hasCustomFilter ||
                                _searchController.text.isNotEmpty)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Reset Pencarian & Filter'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _selectedCategory = 'Semua';
                                    _selectedStockFilter = 'Semua';
                                    _selectedSort = 'default';
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        cartState.items.isNotEmpty ? 96 : 24,
                      ),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 900
                              ? 4
                              : MediaQuery.sizeOf(context).width >= 600
                              ? 3
                              : 2,
                          mainAxisExtent:
                              294 +
                              (MediaQuery.textScalerOf(context).scale(1) - 1) *
                                  190,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final product = filteredProducts[index];
                          final cartItem = cartState.items
                              .where((i) => i.product.sku == product.sku)
                              .firstOrNull;
                          final cartQty = cartItem?.quantity ?? 0;

                          return _ProductCatalogCard(
                            product: product,
                            cartQuantity: cartQty,
                            onAddToCart: () {
                              ref.read(cartProvider.notifier).addItem(product);
                            },
                            onRemoveFromCart: () {
                              if (cartQty <= 1) {
                                ref
                                    .read(cartProvider.notifier)
                                    .removeItem(product.sku);
                              } else {
                                ref
                                    .read(cartProvider.notifier)
                                    .updateQuantity(product.sku, cartQty - 1);
                              }
                            },
                          );
                        }, childCount: filteredProducts.length),
                      ),
                    ),
            ],
          ),

          // Floating Cart Bar (Bottom Quick Checkout Bar)
          if (cartState.items.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _FloatingCartBar(
                itemCount: cartState.totalItemCount,
                totalPrice: cartState.subtotal,
                onCheckout: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CartCheckoutScreen(),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductCatalogCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;
  final int cartQuantity;

  const _ProductCatalogCard({
    required this.product,
    required this.onAddToCart,
    required this.onRemoveFromCart,
    this.cartQuantity = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stock == 0;
    final canAdd = !isOutOfStock && cartQuantity < product.stock;
    final scale = MediaQuery.textScalerOf(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: cartQuantity > 0
              ? AppColors.primaryGreen
              : AppColors.dividerColor,
          width: cartQuantity > 0 ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canAdd ? onAddToCart : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Opacity(
                  opacity: isOutOfStock ? 0.45 : 1,
                  child: ProductArtwork(
                    imagePath: product.imageUrl,
                    category: product.category,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: scale.scale(15) * 2.4,
                    child: Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.tags.isNotEmpty
                        ? '${product.category} · ${product.tags.first}'
                        : product.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOutOfStock ? 'Stok habis' : 'Sisa ${product.stock}',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: switch (product.status) {
                        StockStatus.critical ||
                        StockStatus.outOfStock => AppColors.badgeRedText,
                        StockStatus.low => AppColors.badgeAmberText,
                        StockStatus.safe => AppColors.textSecondary,
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(product.price),
                      style: AppNumbers.price,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (cartQuantity == 0)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: AppButtonStyles.tonal,
                        onPressed: canAdd ? onAddToCart : null,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(isOutOfStock ? 'Habis' : 'Tambah'),
                      ),
                    )
                  else
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          _quantityAction(
                            Icons.remove_rounded,
                            'Kurangi ${product.name}',
                            onRemoveFromCart,
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '$cartQuantity',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                          _quantityAction(
                            Icons.add_rounded,
                            'Tambah ${product.name}',
                            canAdd ? onAddToCart : null,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityAction(IconData icon, String label, VoidCallback? onPressed) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Tooltip(
        message: label,
        child: OutlinedButton(
          style: AppButtonStyles.tonal.copyWith(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          onPressed: onPressed,
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _FloatingCartBar extends StatelessWidget {
  final int itemCount;
  final double totalPrice;
  final VoidCallback onCheckout;

  const _FloatingCartBar({
    required this.itemCount,
    required this.totalPrice,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$itemCount barang',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(totalPrice),
                    style: AppNumbers.metric,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton.icon(
            onPressed: onCheckout,
            label: const Text('Keranjang'),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

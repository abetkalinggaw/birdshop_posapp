import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product.dart';
import 'session_provider.dart';

class InventoryState {
  final List<Product> products;
  final String searchQuery;
  final String selectedCategory;
  final DateTime lastLoaded;

  const InventoryState({
    required this.products,
    this.searchQuery = '',
    this.selectedCategory = 'Semua',
    required this.lastLoaded,
  });

  InventoryState copyWith({
    List<Product>? products,
    String? searchQuery,
    String? selectedCategory,
    DateTime? lastLoaded,
  }) {
    return InventoryState(
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      lastLoaded: lastLoaded ?? this.lastLoaded,
    );
  }

  double get totalAssetValue {
    return products.fold(0.0, (sum, p) => sum + (p.price * p.stock));
  }

  int get totalActiveSku => products.length;

  int get criticalStockCount {
    return products
        .where(
          (p) =>
              p.status == StockStatus.critical ||
              p.status == StockStatus.outOfStock,
        )
        .length;
  }

  List<Product> get filteredProducts {
    return products.where((p) {
      final matchesSearch =
          p.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (selectedCategory == 'Semua') return true;
      if (selectedCategory == 'Stok Aman') return p.status == StockStatus.safe;
      if (selectedCategory == 'Stok Kritis') {
        return p.status == StockStatus.critical ||
            p.status == StockStatus.outOfStock;
      }
      return p.category == selectedCategory;
    }).toList();
  }
}

class InventoryNotifier extends Notifier<InventoryState> {
  @override
  InventoryState build() {
    ref.listen(sessionProvider.select((s) => s.products), (_, products) {
      state = state.copyWith(products: products, lastLoaded: DateTime.now());
    });
    return InventoryState(
      products: ref.read(sessionProvider).products,
      lastLoaded: DateTime.now(),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  Future<void> addProduct(Product product) =>
      ref.read(sessionProvider.notifier).saveProduct(product, isNew: true);

  Future<void> updateProduct(Product product) =>
      ref.read(sessionProvider.notifier).saveProduct(product);

  Future<void> deleteProduct(String sku) =>
      ref.read(sessionProvider.notifier).deleteProduct(sku);

  Future<void> updateStock(String sku, int newStock) =>
      ref.read(sessionProvider.notifier).updateStock(sku, newStock);

  Future<void> refreshInventory() => ref.read(sessionProvider.notifier).load();
}

final inventoryProvider = NotifierProvider<InventoryNotifier, InventoryState>(
  InventoryNotifier.new,
);

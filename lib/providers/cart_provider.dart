import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_item.dart';
import '../models/product.dart';

class CartState {
  final List<CartItem> items;
  final double memberDiscountPercentage;
  final double taxPercentage;

  const CartState({
    required this.items,
    this.memberDiscountPercentage = 0.0,
    this.taxPercentage = 0.0,
  });

  CartState copyWith({
    List<CartItem>? items,
    double? memberDiscountPercentage,
    double? taxPercentage,
  }) {
    return CartState(
      items: items ?? this.items,
      memberDiscountPercentage:
          memberDiscountPercentage ?? this.memberDiscountPercentage,
      taxPercentage: taxPercentage ?? this.taxPercentage,
    );
  }

  int get totalItemCount => items.fold(0, (sum, i) => sum + i.quantity);

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.subtotal);

  double get memberDiscountAmount =>
      subtotal * (memberDiscountPercentage / 100);

  double get taxAmount =>
      (subtotal - memberDiscountAmount) * (taxPercentage / 100);

  double get totalPayment => subtotal - memberDiscountAmount + taxAmount;
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState(items: []);
  }

  void addItem(Product product) {
    final existingIndex = state.items.indexWhere(
      (i) => i.product.sku == product.sku,
    );

    if (existingIndex >= 0) {
      final currentItem = state.items[existingIndex];
      if (currentItem.quantity < product.stock) {
        final updatedItems = [...state.items];
        updatedItems[existingIndex] = currentItem.copyWith(
          quantity: currentItem.quantity + 1,
        );
        state = state.copyWith(items: updatedItems);
      }
    } else {
      if (product.stock > 0) {
        state = state.copyWith(
          items: [
            ...state.items,
            CartItem(product: product, quantity: 1),
          ],
        );
      }
    }
  }

  void updateQuantity(String sku, int quantity) {
    if (quantity <= 0) {
      removeItem(sku);
      return;
    }

    final matchingItems = state.items.where((item) => item.product.sku == sku);
    if (matchingItems.isEmpty) return;
    final product = matchingItems.first.product;
    if (product.stock <= 0) {
      removeItem(sku);
      return;
    }
    final safeQuantity = quantity.clamp(1, product.stock);

    final updatedItems = state.items.map((item) {
      if (item.product.sku == sku) {
        return item.copyWith(quantity: safeQuantity);
      }
      return item;
    }).toList();

    state = state.copyWith(items: updatedItems);
  }

  void removeItem(String sku) {
    state = state.copyWith(
      items: state.items.where((i) => i.product.sku != sku).toList(),
    );
  }

  void clearCart() {
    state = state.copyWith(items: []);
  }

  void setMemberDiscount(double percentage) {
    state = state.copyWith(memberDiscountPercentage: percentage);
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

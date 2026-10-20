import 'package:flutter/material.dart';

import '../models/product.dart';
import '../theme/app_theme.dart';
import 'currency_formatter.dart';
import 'product_artwork.dart';
import 'product_manage_modal.dart';
import 'status_badge.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onManagePressed;
  const ProductCard({super.key, required this.product, this.onManagePressed});

  void _openManageModal(BuildContext context) {
    if (onManagePressed != null) {
      onManagePressed!();
    } else {
      EditProductModal.show(context, product: product);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openManageModal(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: ProductArtwork(
                        imagePath: product.imageUrl,
                        category: product.category,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${product.category} · ${product.sku}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (product.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            product.tags.join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        CurrencyFormatter.format(product.price),
                        style: AppNumbers.price,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusBadge(
                    status: product.status,
                    customLabel: product.stock == 0
                        ? 'Habis'
                        : '${product.stock} unit',
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: 'Kelola ${product.name}',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.actionSurface,
                        foregroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _openManageModal(context),
                      icon: const Icon(Icons.edit_outlined, size: 20),
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
}

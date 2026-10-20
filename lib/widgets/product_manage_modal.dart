import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'primary_button.dart';
import 'product_artwork.dart';

enum ProductModalMode { edit, add }

/// Static facade for backward-compatibility and clean routing
class ProductManageModal {
  static Future<void> show(
    BuildContext context, {
    Product? product,
    ProductModalMode initialMode = ProductModalMode.edit,
  }) {
    if (product != null && initialMode == ProductModalMode.edit) {
      return EditProductModal.show(context, product: product);
    } else {
      return AddProductModal.show(context);
    }
  }

  static Future<void> showEdit(BuildContext context, Product product) {
    return EditProductModal.show(context, product: product);
  }

  static Future<void> showAdd(BuildContext context) {
    return AddProductModal.show(context);
  }
}

/// -------------------------------------------------------------
/// Independent Edit Product Modal Panel (No tab switcher & Device Image Picker)
/// -------------------------------------------------------------
class EditProductModal extends ConsumerStatefulWidget {
  final Product product;

  const EditProductModal({super.key, required this.product});

  static Future<void> show(BuildContext context, {required Product product}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (ctx) => EditProductModal(product: product),
    );
  }

  @override
  ConsumerState<EditProductModal> createState() => _EditProductModalState();
}

class _EditProductModalState extends ConsumerState<EditProductModal> {
  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _tagsController;
  late String _imagePath;
  late String _category;
  bool _busy = false;
  String? _error;

  final List<String> _categories = [
    'Burung Kicau',
    'Pakan & Voer',
    'Sangkar',
    'Obat & Vitamin',
    'Aksesoris',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p.sku);
    _nameController = TextEditingController(text: p.name);
    _priceController = TextEditingController(
      text: p.price % 1 == 0 ? p.price.toStringAsFixed(0) : p.price.toString(),
    );
    _stockController = TextEditingController(text: p.stock.toString());
    _minStockController = TextEditingController(text: p.minStock.toString());
    _tagsController = TextEditingController(text: p.tags.join(', '));
    _imagePath = p.imageUrl;
    _category = _categories.contains(p.category)
        ? p.category
        : _categories.first;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat mengambil foto: $e'),
            backgroundColor: AppColors.alertCritical,
          ),
        );
      }
    }
  }

  void _adjustStock(int delta) {
    final current = int.tryParse(_stockController.text) ?? 0;
    final updated = (current + delta).clamp(0, 99999);
    setState(() {
      _stockController.text = updated.toString();
    });
  }

  void _onSavePressed() {
    if (_busy) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama produk wajib diisi'),
          backgroundColor: AppColors.alertCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show Confirmation Popup Dialog before saving changes
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Simpan Perubahan?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menyimpan perubahan data untuk produk "$name"?',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // close dialog
              _executeSaveProduct();
            },
            child: const Text('Ya, Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeSaveProduct() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? double.nan;
    final stock = int.tryParse(_stockController.text.trim()) ?? -1;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? -1;
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final updatedProduct = Product(
      sku: widget.product.sku,
      name: name,
      category: _category,
      price: price,
      stock: stock,
      minStock: minStock,
      imageUrl: _imagePath,
      tags: tags,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inventoryProvider.notifier).updateProduct(updatedProduct);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Perubahan "$name" berhasil disimpan')),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Produk gagal disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProduct() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(inventoryProvider.notifier)
          .deleteProduct(widget.product.sku);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produk berhasil dihapus')));
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Produk gagal dihapus. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onConfirmDelete() {
    if (_busy) return;
    final p = widget.product;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Produk?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${p.name}" (${p.sku}) dari daftar inventaris?\n\nTindakan ini tidak dapat dibatalkan.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertCritical,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // close dialog
              _deleteProduct();
            },
            child: const Text('Hapus Sekarang'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _ProductEditorSheet(
    title: 'Kelola & Ubah Produk',
    busy: _busy,
    error: _error,
    subtitle: widget.product.name,
    submitLabel: 'Simpan Perubahan',
    stockLabel: 'Stok tersedia',
    skuController: _skuController,
    nameController: _nameController,
    priceController: _priceController,
    stockController: _stockController,
    minStockController: _minStockController,
    tagsController: _tagsController,
    imagePath: _imagePath,
    category: _category,
    categories: _categories,
    readOnlySku: true,
    stockStatus: widget.product.status,
    onCategoryChanged: (value) => setState(() => _category = value),
    onAdjustStock: _adjustStock,
    onCamera: () => _pickImage(ImageSource.camera),
    onGallery: () => _pickImage(ImageSource.gallery),
    onClearPhoto: () => setState(() => _imagePath = ''),
    onSubmit: _onSavePressed,
    onDelete: _onConfirmDelete,
  );
}

/// -------------------------------------------------------------
/// Independent Add Product Modal Panel (No tab switcher & Device Image Picker)
/// -------------------------------------------------------------
class AddProductModal extends ConsumerStatefulWidget {
  const AddProductModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (ctx) => const AddProductModal(),
    );
  }

  @override
  ConsumerState<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends ConsumerState<AddProductModal> {
  late TextEditingController _skuController;
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _minStockController;
  late TextEditingController _tagsController;
  String _imagePath = '';
  String _category = 'Burung Kicau';
  bool _busy = false;
  String? _error;

  final List<String> _categories = [
    'Burung Kicau',
    'Pakan & Voer',
    'Sangkar',
    'Obat & Vitamin',
    'Aksesoris',
  ];

  @override
  void initState() {
    super.initState();
    final autoSku =
        'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    _skuController = TextEditingController(text: autoSku);
    _nameController = TextEditingController();
    _priceController = TextEditingController(text: '50000');
    _stockController = TextEditingController(text: '10');
    _minStockController = TextEditingController(text: '3');
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() {
          _imagePath = picked.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat mengambil foto: $e'),
            backgroundColor: AppColors.alertCritical,
          ),
        );
      }
    }
  }

  void _adjustStock(int delta) {
    final current = int.tryParse(_stockController.text) ?? 0;
    final updated = (current + delta).clamp(0, 99999);
    setState(() {
      _stockController.text = updated.toString();
    });
  }

  void _onAddPressed() {
    if (_busy) return;
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    if (name.isEmpty || sku.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama produk dan SKU wajib diisi'),
          backgroundColor: AppColors.alertCritical,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show Confirmation Popup Dialog before adding product
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tambah Produk Baru?',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah Anda yakin ingin menambahkan produk "$name" ($sku) ke dalam katalog inventaris toko?',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop(); // close dialog
              _executeAddProduct();
            },
            child: const Text('Ya, Tambahkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAddProduct() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? double.nan;
    final stock = int.tryParse(_stockController.text.trim()) ?? -1;
    final minStock = int.tryParse(_minStockController.text.trim()) ?? -1;
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final newProduct = Product(
      sku: sku,
      name: name,
      category: _category,
      price: price,
      stock: stock,
      minStock: minStock,
      imageUrl: _imagePath,
      tags: tags,
    );

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(inventoryProvider.notifier).addProduct(newProduct);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Produk "$name" berhasil ditambahkan')),
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is AuthException
              ? e.message
              : 'Produk gagal disimpan. Coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _ProductEditorSheet(
    title: 'Tambah Produk Baru',
    busy: _busy,
    error: _error,
    subtitle: 'Daftarkan SKU baru ke katalog inventaris toko',
    submitLabel: 'Tambah ke Inventaris',
    stockLabel: 'Stok Masuk Awal',
    skuController: _skuController,
    nameController: _nameController,
    priceController: _priceController,
    stockController: _stockController,
    minStockController: _minStockController,
    tagsController: _tagsController,
    imagePath: _imagePath,
    category: _category,
    categories: _categories,
    readOnlySku: false,

    onCategoryChanged: (value) => setState(() => _category = value),
    onAdjustStock: _adjustStock,
    onCamera: () => _pickImage(ImageSource.camera),
    onGallery: () => _pickImage(ImageSource.gallery),
    onClearPhoto: () => setState(() => _imagePath = ''),
    onSubmit: _onAddPressed,
  );
}

class _ProductEditorSheet extends StatelessWidget {
  final String title, subtitle, submitLabel, stockLabel;
  final TextEditingController skuController,
      nameController,
      priceController,
      stockController,
      minStockController,
      tagsController;
  final String imagePath, category;
  final List<String> categories;
  final bool readOnlySku;
  final bool busy;
  final String? error;
  final StockStatus? stockStatus;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<int> onAdjustStock;
  final VoidCallback onCamera, onGallery, onClearPhoto, onSubmit;
  final VoidCallback? onDelete;

  const _ProductEditorSheet({
    required this.title,
    this.busy = false,
    this.error,
    required this.subtitle,
    required this.submitLabel,
    required this.stockLabel,
    required this.skuController,
    required this.nameController,
    required this.priceController,
    required this.stockController,
    required this.minStockController,
    required this.tagsController,
    required this.imagePath,
    required this.category,
    required this.categories,
    required this.readOnlySku,
    this.stockStatus,
    required this.onCategoryChanged,
    required this.onAdjustStock,
    required this.onCamera,
    required this.onGallery,
    required this.onClearPhoto,
    required this.onSubmit,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight =
        media.size.height - media.padding.top - media.viewInsets.bottom;
    final stackActions =
        media.size.width < 380 || media.textScaler.scale(14) > 17;

    return PopScope(
      canPop: !busy,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(maxHeight: availableHeight * .94),
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                            tooltip: 'Tutup',
                            onPressed: busy
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 22),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: IgnorePointer(
                  ignoring: busy,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (error != null) ...[
                          Text(
                            error!,
                            style: const TextStyle(
                              color: AppColors.alertCritical,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Jumlah Stok Fisik',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (stockStatus != null) ...[
                              const SizedBox(width: 12),
                              StatusBadge(status: stockStatus!),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final fields = [
                              TextField(
                                controller: stockController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryGreen,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                decoration: InputDecoration(
                                  labelText: stockLabel,
                                  constraints: const BoxConstraints(
                                    minHeight: 64,
                                  ),
                                  suffixText: 'unit',
                                ),
                              ),
                              TextField(
                                controller: minStockController,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Min. Kritis',
                                  constraints: BoxConstraints(minHeight: 64),
                                  suffixText: 'unit',
                                ),
                              ),
                            ];
                            if (constraints.maxWidth < 300 ||
                                media.textScaler.scale(14) > 18) {
                              return Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: 16),
                                  fields[1],
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: fields[0]),
                                const SizedBox(width: 12),
                                Expanded(flex: 2, child: fields[1]),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final delta in [-5, -1, 1, 5, 10])
                              TextButton(
                                style: AppButtonStyles.tonal,
                                onPressed: () => onAdjustStock(delta),
                                child: Text(delta > 0 ? '+$delta' : '$delta'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'Detail Informasi Produk',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Nama Produk / Jenis Avian',
                            hintText: 'Contoh: Murai Batu Medan Super',
                          ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final categoryField =
                                DropdownButtonFormField<String>(
                                  initialValue: category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Kategori',
                                  ),
                                  items: categories
                                      .map(
                                        (category) => DropdownMenuItem(
                                          value: category,
                                          child: Text(category),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) onCategoryChanged(value);
                                  },
                                );
                            final sku = TextField(
                              controller: skuController,
                              readOnly: readOnlySku,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(
                                fontSize: 14,
                                color: readOnlySku
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Kode SKU',
                                suffixIcon: readOnlySku
                                    ? const Icon(
                                        Icons.lock_outline,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      )
                                    : null,
                              ),
                            );
                            if (constraints.maxWidth >= 560 &&
                                media.textScaler.scale(14) <= 17) {
                              return Row(
                                children: [
                                  Expanded(child: categoryField),
                                  const SizedBox(width: 16),
                                  Expanded(child: sku),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                categoryField,
                                const SizedBox(height: 16),
                                sku,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          style: AppNumbers.price,
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual Satuan',
                            prefixText: 'Rp ',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: tagsController,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Tag / Varian',
                            hintText: 'Contoh: Ring APBN, Gacor, 500g',
                            helperText: 'Pisahkan setiap tag dengan koma.',
                          ),
                        ),
                        const SizedBox(height: 28),
                        _buildPhotoEditor(),
                      ],
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.dividerColor),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: onDelete == null
                        ? PrimaryButton(
                            text: submitLabel,
                            isLoading: busy,
                            onPressed: busy ? null : onSubmit,
                          )
                        : stackActions
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PrimaryButton(
                                text: submitLabel,
                                isLoading: busy,
                                onPressed: busy ? null : onSubmit,
                              ),
                              const SizedBox(height: 4),
                              _buildDeleteButton(),
                            ],
                          )
                        : Row(
                            children: [
                              _buildDeleteButton(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: PrimaryButton(
                                  text: submitLabel,
                                  isLoading: busy,
                                  onPressed: busy ? null : onSubmit,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() => TextButton.icon(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.badgeRedText,
      minimumSize: const Size(104, 48),
    ),
    onPressed: busy ? null : onDelete,
    icon: const Icon(Icons.delete_outline, size: 20),
    label: const Text('Hapus'),
  );

  Widget _buildPhotoEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Foto Produk',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final preview = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 104,
              child: ProductArtwork(imagePath: imagePath, category: category),
            ),
          );
          final actions = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: onCamera,
                icon: const Icon(Icons.camera_alt_outlined, size: 20),
                label: const Text('Ambil Foto'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Pilih dari Galeri'),
              ),
            ],
          );
          if (constraints.maxWidth < 310 ||
              MediaQuery.textScalerOf(context).scale(14) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [preview, const SizedBox(height: 16), actions],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              preview,
              const SizedBox(width: 16),
              Expanded(child: actions),
            ],
          );
        },
      ),
      if (imagePath.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.badgeRedText),
          onPressed: onClearPhoto,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Hapus Foto'),
        ),
      ],
    ],
  );
}

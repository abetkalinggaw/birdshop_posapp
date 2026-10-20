enum StockStatus { safe, low, critical, outOfStock }

class Product {
  final String sku;
  final String name;
  final String category;
  final double price;
  final int stock;
  final int minStock;
  final String imageUrl;
  final List<String> tags;

  const Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.minStock,
    required this.imageUrl,
    this.tags = const [],
  });

  StockStatus get status {
    if (stock == 0) return StockStatus.outOfStock;
    if (stock <= minStock) return StockStatus.critical;
    if (stock <= minStock + 5) return StockStatus.low;
    return StockStatus.safe;
  }

  Product copyWith({
    String? sku,
    String? name,
    String? category,
    double? price,
    int? stock,
    int? minStock,
    String? imageUrl,
    List<String>? tags,
  }) {
    return Product(
      sku: sku ?? this.sku,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      sku: json['sku'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      minStock: json['minStock'] as int,
      imageUrl: json['imageUrl'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'minStock': minStock,
      'imageUrl': imageUrl,
      'tags': tags,
    };
  }
}

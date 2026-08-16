/// A single stock item a merchant sells.
///
/// `syncStatus` drives the offline-first flow:
///   0 = synced with server, 1 = pending upload, 2 = pending delete
class Product {
  final String id; // UUID, generated on-device so it works fully offline
  final String name;
  final String? category;
  final double costPrice; // what the merchant paid per unit
  final double sellPrice; // retail price
  final double? wholesalePrice; // null = no separate wholesale price set
  final int stockQty;
  final int lowStockThreshold;
  final DateTime updatedAt;
  final int syncStatus;

  const Product({
    required this.id,
    required this.name,
    this.category,
    required this.costPrice,
    required this.sellPrice,
    this.wholesalePrice,
    required this.stockQty,
    this.lowStockThreshold = 5,
    required this.updatedAt,
    this.syncStatus = 1,
  });

  bool get isLowStock => stockQty <= lowStockThreshold;

  double get marginPerUnit => sellPrice - costPrice;

  /// Falls back to the retail price when no wholesale price is set, so
  /// every product is usable for a wholesale sale even before the
  /// merchant bothers configuring tiered pricing.
  double get effectiveWholesalePrice => wholesalePrice ?? sellPrice;

  Product copyWith({
    String? name,
    String? category,
    double? costPrice,
    double? sellPrice,
    double? wholesalePrice,
    int? stockQty,
    int? lowStockThreshold,
    DateTime? updatedAt,
    int? syncStatus,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      stockQty: stockQty ?? this.stockQty,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      updatedAt: updatedAt ?? DateTime.now(),
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'wholesale_price': wholesalePrice,
      'stock_qty': stockQty,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': updatedAt.toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String?,
      costPrice: (map['cost_price'] as num).toDouble(),
      sellPrice: (map['sell_price'] as num).toDouble(),
      wholesalePrice: (map['wholesale_price'] as num?)?.toDouble(),
      stockQty: map['stock_qty'] as int,
      lowStockThreshold: map['low_stock_threshold'] as int? ?? 5,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      syncStatus: map['sync_status'] as int? ?? 0,
    );
  }
}

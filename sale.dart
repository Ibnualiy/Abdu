/// A single sale line (one product sold in one transaction).
/// [customerId] is null for a walk-in retail sale. When set and
/// [isPaidInFull] is false, DatabaseService.insertSale also writes a
/// LedgerEntry so the amount owed shows up on that customer's balance.
class Sale {
  final String id;
  final String productId;
  final String productName; // denormalized so history reads fine offline
  final int quantity;
  final double unitSellPrice;
  final double unitCostPrice; // captured at sale time, protects past profit
  final DateTime soldAt;
  final String? customerId;
  final String? customerName;
  final bool isPaidInFull;
  final String? branchId;
  final String? branchName;
  final int syncStatus;

  const Sale({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitSellPrice,
    required this.unitCostPrice,
    required this.soldAt,
    this.customerId,
    this.customerName,
    this.isPaidInFull = true,
    this.branchId,
    this.branchName,
    this.syncStatus = 1,
  });

  double get revenue => quantity * unitSellPrice;
  double get profit => quantity * (unitSellPrice - unitCostPrice);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_sell_price': unitSellPrice,
      'unit_cost_price': unitCostPrice,
      'sold_at': soldAt.toIso8601String(),
      'customer_id': customerId,
      'customer_name': customerName,
      'is_paid_in_full': isPaidInFull ? 1 : 0,
      'branch_id': branchId,
      'branch_name': branchName,
      'sync_status': syncStatus,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      productId: map['product_id'] as String,
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      unitSellPrice: (map['unit_sell_price'] as num).toDouble(),
      unitCostPrice: (map['unit_cost_price'] as num).toDouble(),
      soldAt: DateTime.parse(map['sold_at'] as String),
      customerId: map['customer_id'] as String?,
      customerName: map['customer_name'] as String?,
      isPaidInFull: (map['is_paid_in_full'] as int? ?? 1) == 1,
      branchId: map['branch_id'] as String?,
      branchName: map['branch_name'] as String?,
      syncStatus: map['sync_status'] as int? ?? 0,
    );
  }
}

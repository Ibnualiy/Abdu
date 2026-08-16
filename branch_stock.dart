/// One product's stock count at one specific branch. Only meaningful
/// once a merchant has created branches (see branch.dart) — a solo,
/// single-location merchant never touches this table at all and keeps
/// using Product.stockQty exactly as before.
///
/// Product.stockQty is NOT replaced by this — it's kept as a running
/// total across all branches (see DatabaseService's stock-adjustment
/// helper), so every existing screen that reads "how much stock does
/// this product have" keeps working unchanged. This table is the
/// additional, branch-specific breakdown of that same total.
class BranchStock {
  final String productId;
  final String branchId;
  final int stockQty;
  final int syncStatus;

  const BranchStock({
    required this.productId,
    required this.branchId,
    required this.stockQty,
    this.syncStatus = 1,
  });

  Map<String, dynamic> toMap() => {
        'id': '${productId}_$branchId',
        'product_id': productId,
        'branch_id': branchId,
        'stock_qty': stockQty,
        'sync_status': syncStatus,
      };

  factory BranchStock.fromMap(Map<String, dynamic> map) => BranchStock(
        productId: map['product_id'] as String,
        branchId: map['branch_id'] as String,
        stockQty: map['stock_qty'] as int,
        syncStatus: map['sync_status'] as int? ?? 0,
      );
}
